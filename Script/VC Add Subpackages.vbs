option explicit

!INC Local Scripts.EAConstants-VBScript

' Script Name: VC_Add subpackages
' Author: Knut Jetlund
' Purpose: Put all subpackages of the selected package to version control
' Date: 20151202

Const strVC  = "SOSI"
Const svnPath = "Andre viktige komponenter\NVDB\NVDB Datakatalogen versjon 2.13\"

sub subPackages2VC
	' Show and clear the script output window
	Repository.ClearOutput "Script"
	Repository.EnsureOutputVisible "Script"
	'Repository.CreateOutputTab "Error"
	'Repository.ClearOutput "Error"
	Repository.ClearOutput "Version Control"
		
	' Get the currently selected package in the tree to work on
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
		
	if not thePackage is nothing then
		dim subP as EA.Package
		for each subP in thePackage.packages
			if subP.VersionControlGetStatus = 0 then
				Repository.WriteOutput "Script", Now & "Setter opp versjonshåndtering for " & subP.Name & " (" & svnPath & subP.Alias & ".xml)",0
				subP.VersionControlAdd strVC,  svnPath & subP.Alias & ".xml", "Initiell versjonering", True
			end if	
		next
	
		Repository.WriteOutput "Script", Now & " Finished, check the Version Control tab", 0 
		Repository.EnsureOutputVisible "Script"
	else
		' No package selected in the tree
		MsgBox( "This script requires a package to be selected in the Project Browser." & vbCrLf & _
			"Please select a package in the Project Browser and try again." )
	end if
end sub

subPackages2VC