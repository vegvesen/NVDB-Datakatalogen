option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

sub recListElement(p)
	dim el as EA.Element
	for each el in p.Elements
		lstSOSIelementNames.Add el.Name
		Repository.WriteOutput "Script", Now & " Element: " & el.Name, 0
	next

	dim subP as EA.Package
	for each subP in p.packages
		Repository.WriteOutput "Script", Now & " Pakke: " & subP.Name, 0
	    recListElement(subP)
	next
end sub

sub main()
	'Lager liste over unike objekttypenavn fra SOSI-modellregister
	connect2models()
	Repository.WriteOutput "Script", Now & " Lager liste med unike objekttypenavn fra SOSI-modellregister", 0 

	Set lstSOSIelementNames = CreateObject("System.Collections.ArrayList")
	Dim pck As EA.Package
    For Each pck In modSOSI.Packages
		If pck.Name = strSOSIGK Or pck.Name = strSOSIGO Then
			Repository.WriteOutput "Script", Now & " Hovedpakke: " & pck.Name, 0 
			recListElement(pck)
		End If
	Next
end sub

main