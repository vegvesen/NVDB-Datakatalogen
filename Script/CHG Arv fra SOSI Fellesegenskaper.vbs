option explicit

!INC Local Scripts.EAConstants-VBScript

' Script Name: Arv fra SOSI-Fellesegenskaper 
' Author: Knut Jetlund
' Purpose: Legger til arv fra SOSI-Fellesegenskaper på alle objekttyper under en pakke (inkl delpakker)
' Date: 20160915
'
' NOTE: Requires a package to be selected in the Project Browser
' 

'Recursive loop through subpackages, and do the thing
sub recPros(p, ft)
	Repository.WriteOutput "Script", Now & " Package: " & p.Name, 0
	dim el as EA.Element
	for each el In p.elements
		if el.Stereotype="featureType" then
			If el.Name = "Dokumentasjon" Or el.Name = "Kommentar" Or el.Name = "Systemobjekt" Or Mid(el.Name, 1, 8) = "Tilstand" Then
				Repository.WriteOutput "Script", Now & " Legger ikke til arv fra SOSI Fellesegenskaper for objekttypen " & el.Name, 0
            Else
				Repository.WriteOutput "Script", Now & " Legger til arv fra SOSI Fellesegenskaper for objekttypen " & el.Name, 0
				dim con as EA.Connector
                set con = el.Connectors.AddNew("", "Generalization")
                con.ClientID = el.ElementID
                con.SupplierID = ft.ElementID
                con.Update()
            End If
		end if

	next
	
	dim subP as EA.Package
	for each subP in p.packages
	    recPros subP, ft
	next
end sub

sub main()
	' Show and clear the script output window
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"
		
	' Get the currently selected package in the tree to work on
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
		
	if not thePackage is nothing and thePackage.ParentID <> 0 then
		Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 
		
		'Finn SOSI Fellesegenskaper
		dim pkSOSIfelles as EA.Package
		set pkSOSIfelles = thePackage.Packages.GetByName("SOSI Fellesegenskaper")
		
		if not pkSOSIfelles is nothing then
			Repository.WriteOutput "Script", Now & " Pakken SOSI Fellesegenskaper funnet (" & pkSOSIfelles.PackageGUID & ")", 0 
			dim ftSOSIfelles as EA.Element
			set ftSOSIfelles = pkSOSIfelles.Elements.GetByName("Fellesegenskaper")
			
			if not ftSOSIfelles is nothing then
				Repository.WriteOutput "Script", Now & " Elementet Fellesegenskaper funnet (" & ftSOSIfelles.ElementGUID & ")", 0 
				recPros thePackage, ftSOSIfelles
				Repository.WriteOutput "Script", Now & " Finished, check the Error and Types tabs", 0 
				Repository.EnsureOutputVisible "Script"
			else
				Repository.WriteOutput "Script", Now & " Finner ikke elementet Fellesegenskaper", 0 
			end if		
		else
			Repository.WriteOutput "Script", Now & " Finner ikke pakken SOSI Fellesegenskaper", 0 
		end if	
	else
		' No package selected in the tree
		MsgBox( "This script requires a package to be selected in the Project Browser." & vbCrLf & _
			"Please select a package in the Project Browser and try again." )
	end if
end sub

main
