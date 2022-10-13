option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre


' Denne filen inneholder funksjoner for oppdatering av klassene for vegobjekttyper i EA-prosjektet. 
'
' Script Name: NVDB til UML.Objekttyper
' Author: Knut Jetlund
' Purpose: Oppdatering av objekttyper
' Date: 20221013
'
' **************************************************************

'Oppdaterer egenskaper på en enkelt vegobjekttype i EA ut i fra Accessbasen
Sub updateProperties_Objekttyper()

	'Dim response
	'response = MsgBox(rsObjekttyper.Fields("NAVN_VOBJ_TYPE").Value, vbOKCancel+vbInformation)
	'If response = vbCancel Then
	'	Exit Sub
	'End If

	element.Name = rsObjekttyper.Fields("NAVN_VOBJ_TYPE").Value
	If Not IsNull(rsObjekttyper.Fields("BSKR_VOBJ_TYPE").Value) Then
		element.Notes = rsObjekttyper.Fields("BSKR_VOBJ_TYPE").Value
		pkOT_Sub.Notes = rsObjekttyper.Fields("BSKR_VOBJ_TYPE").Value
		pkOT_Sub.Update()
	End If
	element.StereotypeEx = ""
	element.Stereotype = "Vegobjekttype"
	element.Status = "Implemented"
	element.Visibility = "Public"
	element.Author = "Dakat"
	element.Version = FC_version
	element.Header1 = ""
	element.Header2 = ""
	element.Gentype = ""
	element.Alias = rsObjekttyper.Fields("ID_VOBJ_TYPE").Value
	element.Modified = Now
	element.Update()
	'Sett versjon på objekttypepakke
	pkOT_Sub.Element.Status = "Implemented"
	pkOT_Sub.Element.Version = FC_version
	pkOT_Sub.Element.Update()
		
	'Fjerner alle eksisterende tagged values 
	For idxT = 0 To element.TaggedValues.Count - 1
		element.TaggedValues.DeleteAt idxT, False
	Next
	For idxT = 0 To pkOT_Sub.Element.TaggedValues.Count - 1
		pkOT_Sub.Element.TaggedValues.DeleteAt idxT, False
	Next
	'Legg til informasjon i nye tagged values
	set tagVal = element.TaggedValues.AddNew("ID_VOBJ_TYPE", rsObjekttyper.Fields("ID_VOBJ_TYPE").Value)
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("NAVN_VOBJ_TYPE", rsObjekttyper.Fields("NAVN_VOBJ_TYPE").Value)
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("KORTN_VOBJ_TYPE", rsObjekttyper.Fields("KORTN_VOBJ_TYPE").Value)
	tagVal.Update()
	If Not IsNull(rsObjekttyper.Fields("SOSINVDB_navn").Value) Then set tagVal = element.TaggedValues.AddNew("SOSINVDB_navn", rsObjekttyper.Fields("SOSINVDB_navn").Value)
	tagVal.Update()
	If rsObjekttyper.Fields("RetningsRelevant").Value = -1 Then set tagVal = element.TaggedValues.AddNew("RetningsRelevant", "true")
	tagVal.Update()
	If Not IsNull(rsObjekttyper.Fields("KjorefeltRelevant").Value) Then set tagVal = element.TaggedValues.AddNew("KjorefeltRelevant", rsObjekttyper.Fields("KjorefeltRelevant").Value)
	tagVal.Update()
	If Not IsNull(rsObjekttyper.Fields("SideposisjonRelevant").Value) Then set tagVal = element.TaggedValues.AddNew("SideposisjonRelevant", rsObjekttyper.Fields("SideposisjonRelevant").Value)
	tagVal.Update()

	'SOSI-navn
	If Not IsNull(rsObjekttyper.Fields("SOSI_navn").Value) Then
		'Hentes fra Datakatalogen 
		set tagVal = element.TaggedValues.AddNew("SOSI_navn", rsObjekttyper.Fields("SOSI_navn").Value)
	Else
		'Genereres dersom blankt i Datakatalogen. Fjerner ulovlige tegn, og setter inn store forbokstaver. Maks lengde 32 tegn, ikke kontroll for unikt i SOSI
		set tagVal = element.TaggedValues.AddNew("SOSI_navn", createSOSInavn(rsObjekttyper.Fields("NAVN_VOBJ_TYPE").Value, "",64,""))
	End If
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("Stedfesting", rsObjekttyper.Fields("Stedfesting").Value)
	tagVal.Update()
	If Not IsNull(rsObjekttyper.Fields("Dato_fra").Value) Then 
		set tagVal = element.TaggedValues.AddNew("ObjektlisteFerdigveg", "true")
		tagVal.Update()
		set tagVal = pkOT_Sub.Element.TaggedValues.AddNew("ObjektlisteFerdigveg", "true")
		tagVal.Update()
	end if	
	element.TaggedValues.Refresh()
	
End Sub

'Oppdaterer egenskaper på alle vegobjekttyper i EA ut i fra Accessbasen
sub updateObjekttyper()
	'Setter opp kobling til modeller og databasetabell
	connect2models
	set rsObjekttyper = CreateObject("ADODB.Recordset")
	rsObjekttyper.Open "SELECT * FROM VEGOB_TYPE WHERE NAVN_VOBJ_TYPE NOT LIKE 'Utgår%'", dbDakat, 3, 1
    rsObjekttyper.Filter = "Dato_fra_nvdb <> NULL"
    rsObjekttyper.MoveLast()
    Repository.WriteOutput "Script", Now & " Oppdaterer vegobjekttyper og legger til nye", 0 

   	'Sett versjon på hovedpakka
	pkObjekttyper.Element.Status = "Implemented"
	pkObjekttyper.Element.Version = FC_version
	pkObjekttyper.Element.Update

	'Kjører gjennom alle pakker for vegobjekttyper i EA. Oppdaterer eksisterende pakker og objekttyper, sletter utgåtte
	id = 0
	Set lstAlias = CreateObject("System.Collections.ArrayList")
	For idxP = 0 To pkObjekttyper.Packages.Count - 1
		set pkOT_Sub = pkObjekttyper.Packages.GetAt(idxP)
		id = pkOT_Sub.Alias
		'Tester om objekttypen denne pakken representerer finnes i Dakat
		rsObjekttyper.MoveFirst()
		rsObjekttyper.Find("ID_VOBJ_TYPE=" & id)
		If not rsObjekttyper.EOF Then
			'Objekttypen eksisterer i Dakat --> Oppdater pakke og objekttype
			'Oppdaterer pakkenavnet
			pkOT_Sub.Name = rsObjekttyper.Fields("NAVN_VOBJ_TYPE").Value
			pkOT_Sub.Update()
			'Søker etter selve objekttypen i pakken
			set element = getElementByAlias(pkOT_Sub, id)
			if not element is nothing then
				'Oppdaterer objekttypen
				Repository.WriteOutput "Script", Now & " Oppdaterer vegobjekttype: " & rsObjekttyper.Fields("NAVN_VOBJ_TYPE").Value & " (" & rsObjekttyper.Fields("ID_VOBJ_TYPE").Value & ")", 0
				updateProperties_Objekttyper()
			else	
				'Selve objekttypen eksisterer ikke i pakken, må da opprettes
				Repository.WriteOutput "Endringer", Now & " Lager ny vegobjekttype: " & rsObjekttyper.Fields("NAVN_VOBJ_TYPE").Value & " (" & rsObjekttyper.Fields("ID_VOBJ_TYPE").Value & ")", 0
				set element = pkOT_Sub.Elements.AddNew(rsObjekttyper.Fields("NAVN_VOBJ_TYPE").Value, "Class")
				element.Update()
				updateProperties_Objekttyper()
				'Lager nytt tomt diagram
				set eDiagram = pkOT_Sub.Diagrams.AddNew(pkOT_Sub.Name, "Logical")
				eDiagram.Update()
			end if 
			lstAlias.Add(id)
		Else
			'Objekttypen finnes ikke i Dakat, eller skal utgå. Sletter hele pakken fra EA
			Repository.WriteOutput "Endringer", Now & " Sletter utgått vegobjekttype: " & pkOT_Sub.Name & " (" & id & ")", 0
			pkObjekttyper.Packages.DeleteAt idxP, False 
		End If
	Next 
	
	'Kjører gjennom alle registrerte objekttyper i Dakat, og legger til manglende i EA
	rsObjekttyper.MoveFirst()
	Do Until rsObjekttyper.EOF
		id = cstr(rsObjekttyper.Fields("ID_VOBJ_TYPE").Value)
		If Not lstAlias.Contains(id) Then
			'Pakke med angitt alias finnes ikke i modellen. Må legges til.
			Repository.WriteOutput "Endringer", Now & " Lager ny vegobjekttype: " & rsObjekttyper.Fields("NAVN_VOBJ_TYPE").Value & " (" & rsObjekttyper.Fields("ID_VOBJ_TYPE").Value & ")",0
			'Legger til pakke som representerer objekttypen
			set pkOT_Sub = pkObjekttyper.Packages.AddNew(rsObjekttyper.Fields("NAVN_VOBJ_TYPE").Value, "Package")
			pkOT_Sub.Update()
			pkOT_Sub.Element.Alias = rsObjekttyper.Fields("ID_VOBJ_TYPE").Value
			pkOT_Sub.Update()
			'Legger til selve objekttypen
			set	element = pkOT_Sub.Elements.AddNew(rsObjekttyper.Fields("NAVN_VOBJ_TYPE").Value, "Class")
			element.Update()
			updateProperties_Objekttyper()
		Else
			Repository.WriteOutput "Script", Now & " Vegobjekttypen finnes: " & rsObjekttyper.Fields("NAVN_VOBJ_TYPE").Value & " (" & rsObjekttyper.Fields("ID_VOBJ_TYPE").Value & ")", 0
		End If
		rsObjekttyper.MoveNext()
	Loop

	'Alfabetisk sortering av pakker, slik at nye eller omdøpte pakker havner på riktig plass i trestrukturen
	Repository.WriteOutput "Script", Now & " Sorterer pakker etter navn, bygger liste...",0
	pkObjekttyper.Packages.Refresh()
	dim lstPck
	set lstPck = CreateObject("System.Collections.Sortedlist")
	For idxP = 0 To pkObjekttyper.Packages.Count - 1
		set pkOT_Sub = pkObjekttyper.Packages.GetAt(idxP)
		lstPck.Add pkOT_Sub.Name, pkOT_Sub.PackageGUID
	Next 
	dim i
	for i = 0 To lstPck.Count - 1
		set pkOT_Sub = Repository.GetPackageByGuid(lstPck.GetByIndex(i))
		pkOT_Sub.TreePos=i+1
		pkOT_Sub.Update			
		Repository.WriteOutput "Script", Now & " Ny posisjon " & i & " for pakke " & pkOT_Sub.Name ,0
	next	
	Repository.RefreshModelView (pkObjekttyper.PackageID)

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"

end sub

updateObjekttyper
