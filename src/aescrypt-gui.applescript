--
-- AES Crypt Launcher for Mac
-- Copyright (C) 2024
-- Terrapane Corporation
-- Author: Paul E. Jones <paulej@packetizer.com>
--

-- Handler to run when the user opens AES Crypt
on run
	local file_list

	-- Ensure the application is brought to the front
	activate

	try
		set file_list to choose file ¬
			with prompt "Select file(s) to encrypt or decrypt" ¬
			with multiple selections allowed
	on error e number error_number
		if error_number is -128 then
			-- User pressed "Cancel"
			set file_list to {}
		else
			-- All other errors will render a message
			MessageDialog("An error occurred: " & (e as text))
			set file_list to {}
		end if
	end try

	-- If the user selected one or more files, process the file(s)
	if (count of file_list) is not 0 then
		open(file_list)
	end if
end run

-- Handler to run when processing files (either from on run() or drag/drop)
on open(file_list)
	local mode
	local user_password

	-- Ensure the application is brought to the front
	activate

	try
		-- Ensure that all items dropped are files
		if not VerifyFiles(file_list) then
			MessageDialog("Only regular files can be processed.")
			return
		end if

		-- Decide if encrypting if any file does not end in .aes
		set mode to DetermineOperationalMode(file_list)
		if mode is equal to "" then
			return
		end if

		-- Prompt the user for a password
		set user_password to PromptPassword(mode)
		if user_password is equal to "" then
			return
		end if

		-- Iterate over all files, encrypting or decrypting as appropriate
		PerformOperations(mode, file_list, user_password)
	on error e
		MessageDialog("Unexpected error: " & (e as text))
	end try
end open

-- Show a message dialog window to the user having the specified message
on MessageDialog(message)
	local script_location
	local icon_file

	set script_location to (path to me) as text
	set icon_file to script_location & "Contents:Resources:aescrypt_lock.icns"

	display dialog message ¬
		with title "AES Crypt" ¬
		buttons "OK" ¬
		default button "OK" ¬
		with icon file icon_file
end MessageDialog

-- Ensure all of the given names are regular files
on VerifyFiles(file_list)
	local file_list_item
	local posix_path
	local file_type

	repeat with file_list_item in file_list
		set posix_path to quoted form of (POSIX path of file_list_item)
		set file_type to (do shell script "file -b -i " & posix_path)
		if file_type is not equal to "regular file" then
			return false
		end if
	end repeat

	return true
end VerifyFiles

-- Determine if encrypting/decrypting based on file names
-- (Any list having a file no ending in .aes triggers encryption)
on DetermineOperationalMode(file_list)
	local normal_files
	local aes_files

	set normal_files to false
	set aes_files to false

	repeat with file_list_item in file_list
		set file_extension to name extension of (info for file_list_item)
		ignoring case
			if file_extension is equal to "aes" then
				set aes_files to true
			else
				set normal_files to true
			end if
		end ignoring
	end repeat

	if normal_files is true and aes_files is true then
		MessageDialog("Cannot process both AES Crypt and non-AES Crypt " & ¬
		              "files at the same time.")
		return ""
	end if

	if normal_files is true then
		return "e"
	end if

	-- Default mode is decryption
	return "d"
end DetermineOperationalMode

-- Render the password dialog with the given message, returning the an empty
-- string on error or if the user presses "Cancel"
on PasswordDialog(message)
	local script_location
	local icon_file
	local user_password

	set script_location to (path to me) as text
	set icon_file to script_location & "Contents:Resources:aescrypt_lock.icns"
	set user_password to ""

	-- Repeatedly prompt for a password until provided or "Cancel" is pressed
	repeat while user_password is equal to ""
		try
			set user_password to text returned of ( ¬
				display dialog message with title "AES Crypt" ¬
				default answer "" ¬
				buttons {"Cancel", "OK"} ¬
				default button "OK" ¬
				with icon file icon_file ¬
				with hidden answer)
		on error e number error_number
			if error_number is -128 then
				-- User pressed "Cancel"
				set user_password to ""
				exit repeat
			else
				-- All other errors will render a message
				MessageDialog("An error occurred: " & (e as text))
				set user_password to ""
				exit repeat
			end if
		end try
		if user_password is equal to "" then
			MessageDialog("A password must be provided.")
		end if
	end repeat

	return user_password
end PasswordDialog

-- Prompts the user for a password, returning "" if the user clicks "Cancel"
on PromptPassword(mode)
	local script_location
	local icon_file
	local user_password
	local verify_password

	set script_location to (path to me) as text
	set icon_file to script_location & "Contents:Resources:aescrypt_lock.icns"
	set user_password to ""

	-- Loop until a password is acquired or user cancels the password prompt
	repeat while user_password is ""
		-- Textual version of the mode to show the user
		if mode is equal to "e" then
			set mode_text to "encryption"
		else
			set mode_text to "decryption"
		end if
		set message to "Enter password for " & mode_text

		-- Render the dialog box and allow for the user to cancel
		set user_password to PasswordDialog(message)
		if user_password is ""
			exit repeat
		end if

		-- If encrypting, verify the user's password
		if mode is equal to "e" then
			set verify_password to PasswordDialog("Verify the password")
			if verify_password is ""
				set user_password to ""
				exit repeat
			end if
			if verify_password is not equal to user_password then
				MessageDialog("The passwords entered do not match.")
				set user_password to ""
			end if
		end if
	end repeat

	return user_password
end PromptPassword

-- Get the user's locale information
on GetUserLocale()
	local user_locale

	try
		set user_locale to user locale of (system info)
	on error
		return ""
	end try

	return user_locale
end GetUserLocale

-- Get character encoding for AES Crypt (User's locale + UTF-8)
on GetCharacterEncoding()
	local locale_list
	local user_locale

	try
		-- Get the list of locales
		set locale_list to do shell script "locale -a"

		-- Get the user's locale from the system, assuming UTF-8 for encoding
		set user_locale to GetUserLocale() & ".UTF-8"

		-- Able to get the locale string (more than just the .UTF-8 part)?
		if user_locale is not equal to ".UTF-8" then
			-- If the user's locale is in the list, use it
			if locale_list contains user_locale then
				return user_locale
			end if
		end if

		-- Attempt to fall back to en_US.UTF-8 and use it if available
		set user_locale to "en_US.UTF-8"
		if locale_list contains user_locale then
			return user_locale
		end if
	on error
		return ""
	end try

	return ""
end GetCharacterEncoding

-- Perform encryption or decryption operations
on PerformOperations(mode, file_list, password)
	local user_locale
	local script_location
	local aescrypt
	local pw
	local file_list_item
	local file_path

	-- Determine the locale to use
	set user_locale to GetCharacterEncoding()
	if user_locale is equal to "" then
		MessageDialog("Unable to determine a suitable character encoding. " & ¬
					  "Contact support for assistance. (" & ¬
					  GetUserLocale() & ")")
		return
	end if

	set script_location to (path to me) as text
	set aescrypt to quoted form of ( ¬
		POSIX path of (script_location & "Contents:MacOS:aescrypt"))

	-- We must use a quoted form of the password
	set pw to quoted form of password

	try
		-- Iterate over each file, encrypting or decrypting
		repeat with file_list_item in file_list
			set file_path to quoted form of (POSIX path of file_list_item)
			do shell script ( ¬
				"LANG=" & user_locale & space & aescrypt & ¬
				" -q -" & mode & " -p " & pw & space & file_path)
		end repeat
	on error e
		MessageDialog(e as text)
		return
	end try

	if mode is equal to "e" then
		MessageDialog("File(s) were encrypted successfully.")
	else
		MessageDialog("File(s) were decrypted successfully.")
	end if
end PerformOperations
