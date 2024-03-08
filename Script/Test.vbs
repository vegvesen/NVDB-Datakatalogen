option explicit


!INC NVDB._felles

Sub test
	'dim str
	'str = createSOSInavn( "1-2", "lower", 50, "")
	
	'dim objRegEx
	'Set objRegEx = CreateObject("VBScript.RegExp")

	'objRegEx.Global = True
	'objRegEx.Pattern = "([0-9]*)([.][-])([0-9]*)"

	dim strSearchString
	strSearchString = "Bruksklasse, 12/65 mobilkran m.m."
	dim strNewString
	strNewString =createSOSInavn(strSearchString, "Lower", 255, "")
	'strNewString = objRegEx.Replace (strSearchString, "$1til$3")

	Repository.WriteOutput "Script", Now & " " & strNewString, 0 

end sub

test()