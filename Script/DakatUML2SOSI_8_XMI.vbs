option explicit

!INC Local Scripts.EAConstants-VBScript
									   
!INC NVDB._felles
!INC NVDB._parametre
								 

' Script Name: DakatUML2SOSI_8_XMI
' Author: Knut Jetlund
' Purpose: Eksporterer SOSI-UML-pakker til XMI
' Date: 2020-05-27


sub exportPackages()
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"

	' Get the currently selected package in the tree to work on
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
		
	if not thePackage is nothing and thePackage.ParentID <> 0 then
		
	Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 
	dim pck as EA.Package
	dim pI as EA.Project					
	set pI = Repository.GetProjectInterface()
	'Eksporterer alle pakker 
	for each pck in thePackage.Packages			
		'pck.StereotypeEx = ""
		'pck.Update
		Repository.WriteOutput "Script", Now & " Eksporter filen " & sosiPath & "\" & pck.Alias & ".xml", 0 
		pI.ExportPackageXMI pck.PackageGUID, 12, 1, -1, 1, 0, sosiPath & "\" & pck.Alias & ".xml"				
	next
	
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"
end sub

exportPackages()