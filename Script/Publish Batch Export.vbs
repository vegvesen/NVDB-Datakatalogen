option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._parametre

' Script Name: 
' Author: 
' Purpose: 
' Date: 

function exportPackages()
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"

	' Get Vegobjekttyper package
	dim thePackage as EA.Package
	set thePackage = Repository.GetPackageByGuid(guidNVDBVegobjekttyper)
		
	if not thePackage is nothing and thePackage.ParentID <> 0 then
		
		Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 
		dim pck as EA.Package
		dim pI as EA.Project					
		set pI = Repository.GetProjectInterface()
		'Eksporterer alle pakker 
		for each pck in thePackage.Packages	
			if pck.PackageGUID <> guidAbstrakteKlasser then 'Not neccessary here, but doesnt ruin anything
				Repository.WriteOutput "Script", Now & " Eksporter filen " & umlPath & "\" & pck.Alias & ".xml", 0 
				pI.ExportPackageXMI pck.PackageGUID, 0, 1, -1, 1, 0, umlPath & "\" & pck.Alias & ".xml"		
			end if		
		next
	
		Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	end if
	Repository.EnsureOutputVisible "Script"
end function

'exportPackages