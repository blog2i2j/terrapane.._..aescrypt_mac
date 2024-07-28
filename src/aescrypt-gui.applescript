--
-- AES Crypt Launcher for Mac
-- Copyright (C) 2024
-- Terrapane Corporation
-- Author: Paul E. Jones <paulej@packetizer.com>
--

-- Handler to run when the user attempts to open the app without presenting files
on run
	-- Ensure the application is brought to the front
	activate

	-- Report that one cannot open the application without a file list
	ReportError("To encrypt or decrypt files with AES Crypt, drag and drop files onto application lock icon. You may place the lock icon on the dock for convenience.")
end run

-- Handler to run when files are dropped on to the lock icon
on open (file_list)
	try
		-- Ensure that all items dropped are files
		if not VerifyFiles(file_list) then
			ReportError("Only regular files can be processed.")
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

		-- Iterate over all files, encrypting or decrpyting as appropriate
		PerformOperations(mode, file_list, user_password)
	on error e
		ReportError("Unexpected error: " & (e as text))
	end try
end open

-- Handler to report errors to the user
on ReportError(message)
	set script_location to (path to me) as text
	set icon_file to script_location & "Contents:Resources:aescrypt_lock.icns"

	display dialog message with title "AES Crypt" buttons "OK" default button "OK" with icon file icon_file
end ReportError

-- Ensure all of the given names are regular files
on VerifyFiles(file_list)
	repeat with file_list_item in file_list
		set posix_path to quoted form of (POSIX path of file_list_item)
		set file_type to (do shell script "file -b -i " & posix_path)
		if file_type is not "regular file" then
			return false
		end if
	end repeat

	return true

end VerifyFiles

-- Determine if encrypting/decrypting based on file names
-- (Any list having a file no ending in .aes triggers encryption)
on DetermineOperationalMode(file_list)
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
		ReportError("Cannot process both AES Crypt and non-AES Crypt files at the same time.")
		return ""
	end if

	if normal_files is true then
		return "e"
	end if

	-- Default mode is decryption
	return "d"
end DetermineOperationalMode

-- Prompts the user for a password, returning "" if the user cancels or no password given
on PromptPassword(mode)
	set script_location to (path to me) as text
	set icon_file to script_location & "Contents:Resources:aescrypt_lock.icns"
	set seeking_input to true

	-- Loop until a password is acquired
	repeat while seeking_input is true
		set user_password to ""
		set verify_passwird to ""

		-- Textual version of the mode to show the user
		if mode is equal to "e" then
			set mode_text to "encryption"
		else
			set mode_text to "decryption"
		end if
		set message to "Enter password for " & mode_text

		-- Render the dialog box and allow for the user to cancel
		repeat while user_password is equal to ""
			try
				set user_password to text returned of (display dialog message with title "AES Crypt" default answer "" buttons {"Cancel", "OK"} default button "OK" with icon file icon_file with hidden answer)
			on error
				-- Generally, the user pressed
				return ""
			end try
			if user_password is equal to "" then
				ReportError("A password must be provided.")
			end if
		end repeat

		-- If encrypting, verify the user's password
		if mode is equal to "e" then
			try
				set verify_password to text returned of (display dialog "Verify your password" with title "AES Crypt" default answer "" buttons {"Cancel", "OK"} default button "OK" with icon file icon_file with hidden answer)
			on error
				-- Generally, user pressed Cancel
				return ""
			end try
			if verify_password is not equal to user_password then
				ReportError("The passwords entered do not match.")
			else
				set seeking_input to false
			end if
		else
			set seeking_input to false
		end if
	end repeat

	return user_password

end PromptPassword

-- Routine to perform encrypt or decrypt operations
on PerformOperations(mode, file_list, password)
	-- We must ensure the locale is UTF-8
	set user_locale to user locale of (system info) & ".UTF-8"

	set script_location to (path to me) as text
	set aescrypt to quoted form of (POSIX path of (script_location & "Contents:MacOS:aescrypt"))

	-- We must use a quoted form of the password
	set pw to quoted form of password

	try
		-- Iterate over each file, encrypting or decrypting, stopping on any error
		repeat with file_list_item in file_list
			set file_path to quoted form of (POSIX path of file_list_item)
			do shell script ("LANG=" & user_locale & space & aescrypt & " -q -" & mode & " -p " & pw & space & file_path)
		end repeat
	on error e
		ReportError(e as text)
		return
	end try

	if mode is equal to "e" then
		ReportError("File(s) were encrypted successfully.")
	else
		ReportError("File(s) were decrypted successfully.")
	end if
end PerformOperations
