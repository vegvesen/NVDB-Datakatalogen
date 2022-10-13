option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre


' Denne filen inneholder funksjoner for oppdatering av NVDB-Datatyper i EA-prosjektet. 
'
' Script Name: NVDB til UML.Datatyper
' Author: Knut Jetlund
' Purpose: Oppdatering av datatyper
' Date: 20221013
'
' **************************************************************

'Prosedyre for å oppdaterer egenskaper på en enkelt datatype i EA ut i fra Accessdatabasen
Sub updateProperties_Datatyper()
	element.Name = rsDatatyper.Fields("NAVN_DATATYP").Value
	element.Alias = rsDatatyper.Fields("ID_DATATYPE").Value
	If Not IsNull(rsDatatyper.Fields("Beskr_datatype").Value) Then element.Notes = rsDatatyper.Fields("Beskr_datatype").Value
	element.StereotypeEx = ""
	element.Stereotype = "dataType"
	element.Status = "Implemented"
	element.Visibility = "Public"
	element.Author = "Dakat"
	element.Gentype = ""
	element.Version = FC_version
	element.Modified = Now
	element.Update()
	'Fjerner alle eksisterende tagged values 
	For idxT = 0 To element.TaggedValues.Count - 1
		element.TaggedValues.DeleteAt idxT, False
	Next 
	'Legger til informasjon i nye tagged values
	set tagVal = element.TaggedValues.AddNew("Kortnavn", rsDatatyper.Fields("Kortnavn").Value)
	tagVal.Update()
	element.TaggedValues.Refresh()
	set tagVal = element.TaggedValues.AddNew("ID", rsDatatyper.Fields("ID_DATATYPE").Value)
	tagVal.Update()
	element.TaggedValues.Refresh()
	'Legger til mapping til SOSI-datatype som tagged value
	Select Case element.Alias
		Case 1 : set tagVal = element.TaggedValues.AddNew("SOSI_type", "CharacterString")
		Case 2 : set tagVal = element.TaggedValues.AddNew("SOSI_type", "Real")
		Case 8 : set tagVal = element.TaggedValues.AddNew("SOSI_type", "Date")
		Case 9 : set tagVal = element.TaggedValues.AddNew("SOSI_type", "CharacterString")
		Case 10 : set tagVal = element.TaggedValues.AddNew("SOSI_type", "CharacterString")
		Case 17 : set tagVal = element.TaggedValues.AddNew("SOSI_type", "Punkt")
		Case 18 : set tagVal = element.TaggedValues.AddNew("SOSI_type", "Kurve")
		Case 19 : set tagVal = element.TaggedValues.AddNew("SOSI_type", "Flate")
		Case 28 : set tagVal = element.TaggedValues.AddNew("SOSI_type", "Boolean")
	End Select
	tagVal.Update()
	element.TaggedValues.Refresh()
End Sub

'Prosedyre for å oppdatere alle datatyper i EA ut i fra Accessdatabasen
sub updateDatatyper()
	'Setter opp kobling til modeller og databasetabell
	connect2models
	set rsDatatyper = CreateObject("ADODB.Recordset")
	rsDatatyper.Open "DATATYPE", dbDakat, 3, 1
	Repository.WriteOutput "Script", Now & " Oppdaterer datatyper og legger til nye", 0 
	Repository.WriteOutput "Script", Now & "", 0   
   	'Sett versjon på hovedpakka
	pkDatatyper.Element.Status = "Implemented"
	pkDatatyper.Element.Version = FC_version
	pkDatatyper.Element.Update
	'Kjører gjennom alle registrerte datatyper i EA og sammenligner med Accessbasen. Oppdaterer eksisterende, sletter utgåtte
	id = 0
	'Lager aliasliste for lagring av id-er i EA
	Set lstAlias = CreateObject("System.Collections.ArrayList")
	'Løkke for alle datatyper i EA
	For idxe = 0 To pkDatatyper.Elements.Count - 1
        set element = pkDatatyper.Elements.GetAt(idxe)
        id = element.Alias
        'Søker etter datatypen i Dakat
        rsDatatyper.MoveFirst()
        rsDatatyper.Find("ID_DATATYPE=" & id)
        If Not rsDatatyper.EOF Then
			'Datatypen finnes - oppdater egenskaper
			Repository.WriteOutput "Script", Now & " Oppdaterer datatype: " & rsDatatyper.Fields("NAVN_DATATYP").Value & " (" & rsDatatyper.Fields("ID_DATATYPE").Value & ")", 0 
            updateProperties_Datatyper()
            lstAlias.Add id
        Else
            'Datatypen finnes ikke i Dakat - slettes
			Repository.WriteOutput "Endringer", Now & " Sletter utgått datatype: " & element.Name & " (" & id & ")", 0 
            pkDatatyper.Elements.DeleteAt idxe, False
        End If
    Next 
	
	'Kjører gjennom alle registrerte datatyper i Dakat og sammenligner med EA. Legger til manglende i EA
    Repository.WriteOutput "Script", Now & " Kontroll av manglende datatyper",0
	rsDatatyper.MoveFirst()
    Do Until rsDatatyper.EOF
		id = cstr(rsDatatyper.Fields("ID_DATATYPE").Value)
        If lstAlias.Contains(id) Then
			'Finnes i EA. Ingen endring. 
            Repository.WriteOutput "Script", Now & " Datatypen finnes i modellen: " & rsDatatyper.Fields("NAVN_DATATYP").Value & " (" & rsDatatyper.Fields("ID_DATATYPE").Value & ")",0
        Else
            'Datatype med angitt alias finnes ikke i EA, må legges til.
            Repository.WriteOutput "Endringer", Now & " Lager datatype: " & rsDatatyper.Fields("NAVN_DATATYP").Value & " (" & rsDatatyper.Fields("ID_DATATYPE").Value & ")",0
            set element = pkDatatyper.Elements.AddNew(rsDatatyper.Fields("NAVN_DATATYP").Value, "Class")
            element.Update()
            updateProperties_Datatyper()
        End If
        rsDatatyper.MoveNext()
    Loop
	
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"

end sub

updateDatatyper
