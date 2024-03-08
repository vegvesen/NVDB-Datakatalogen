option explicit

!INC Local Scripts.EAConstants-VBScript
									   
						 

' Script Name: DakatUML2SOSI_8_XMI
' Author: Knut Jetlund
' Purpose: Eksporterer SOSI-UML-pakker til XMI
' Date: 2020-05-27


sub main()
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
		set pck = thePackage
		'for each pck in thePackage.Packages	
			Repository.WriteOutput "Script", Now & " Pakke: " & pck.Name & " (" & pck.PackageGUID & ")", 0 
			dim el as EA.Element
			for each el in pck.Elements
				Repository.WriteOutput "Script", Now & " Klasse: " & el.Name & " (" & el.ElementID & ")", 0 
				dim con as EA.Connector
				dim ic 
				for ic = 1 to el.Connectors.Count - 1
					set con = el.Connectors.GetAt(ic)
					Repository.WriteOutput "Script", Now & " Relasjon: " & con.Type & " mellom " & con.ClientID & " og " & con.SupplierID , 0 
					'If con.Type = "Aggregation" then
						'el.Connectors.DeleteAt ic, false
					'end if
				
				next
			
			next		
		'next
	
		Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	end if
	Repository.EnsureOutputVisible "Script"
end sub

main