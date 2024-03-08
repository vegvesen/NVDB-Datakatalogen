option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre


' Denne filen inneholder funksjoner for oppdatering av attributter (egenskapstyper) for vegobjekttyper i EA-prosjektet. 
'
' Script Name: NVDB til UML.Egenskapstyper
' Author: Knut Jetlund
' Purpose: Oppdatering av egenskapstyper
' Date: 20220919
'
' **************************************************************

'Oppdaterer egenskaper (properties) på en enkelt egenskapstype (attributt) i EA ut i fra Dakat
Sub updateProperties_Egenskapstyper()

	Dim idxDataType 
	Dim elementDT As EA.Element

	eAttributt.Name = rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value
	If Not IsNull(rsEgenskapstyper.Fields("BSKR_EGENSKAPSTYPE").Value) Then 
		eAttributt.Notes = rsEgenskapstyper.Fields("BSKR_EGENSKAPSTYPE").Value
	else
		eAttributt.Notes = ""
	end if	

	For idxDataType = 0 To pkDatatyper.Elements.Count - 1
		set elementDT = pkDatatyper.Elements.GetAt(idxDataType)				
		If elementDT.Alias = cstr(rsEgenskapstyper.Fields("ID_DATATYPE").Value) Then
			eAttributt.Type = elementDT.Name
			eAttributt.ClassifierID = elementDT.ElementID
			idxDataType = pkDatatyper.Elements.Count - 1
		End If
	Next 
	eAttributt.Visibility = "Public"
	eAttributt.Style = rsEgenskapstyper.Fields("ID_EGENSKAPSTYPE").Value
	eAttributt.LowerBound = 0
	If Not IsNull(rsEgenskapstyper.Fields("Viktighet").Value) Then
		If Not IsNull(rsEgenskapstyper.Fields("Viktighet").Value) And (rsEgenskapstyper.Fields("Viktighet").Value = 1 Or rsEgenskapstyper.Fields("Viktighet").Value = 2) Then
			'1=Påkrevd, absolutt krav i database. 2=Påkrevd, men ikke absolutt  krav i database. 
			eAttributt.LowerBound = 1
		ElseIf rsEgenskapstyper.Fields("Viktighet").Value = 3 Then
			'3=Betinget ( angis i feltet "merknad_registrering"). 
			'Legg til constraint på objekttypen: "[Egenskapsnavn] : & [merknad_registrering]"
			set constraint = element.Constraints.AddNew(eAttributt.Name & ": " & rsEgenskapstyper.Fields("merknad_registrering").Value, "Invariant")
			constraint.Status = "Approved"
			constraint.Update()
			Repository.WriteOutput "Script", Now & " Lager constraint: " & constraint.Name,0
		End If
	End If
	eAttributt.UpperBound = 1
	If Not IsNull(rsEgenskapstyper.Fields("TOTAL_FELTLENGDE").Value) Then eAttributt.Length = rsEgenskapstyper.Fields("TOTAL_FELTLENGDE").Value
	If Not IsNull(rsEgenskapstyper.Fields("ANTALL_DESIMALER").Value) Then eAttributt.Precision = rsEgenskapstyper.Fields("ANTALL_DESIMALER").Value
	If Not IsNull(rsEgenskapstyper.Fields("DEFAULTVERDI").Value) Then eAttributt.Default = rsEgenskapstyper.Fields("DEFAULTVERDI").Value
	If Not IsNull(rsEgenskapstyper.Fields("NR_EGENSKAPSTYPE").Value) Then eAttributt.Pos = rsEgenskapstyper.Fields("NR_EGENSKAPSTYPE").Value
	eAttributt.Update()

	'Fjerner alle eksisterende tagged values og legger til på nytt
	For idxT = 0 To eAttributt.TaggedValues.Count - 1
		eAttributt.TaggedValues.DeleteAt idxT, False
	Next 
	set aTag = eAttributt.TaggedValues.AddNew("ID_EGENSKAPSTYPE", rsEgenskapstyper.Fields("ID_EGENSKAPSTYPE").Value)
	aTag.Update()
	set aTag = eAttributt.TaggedValues.AddNew("NAVN_EGENSKAPSTYPE", rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value)
	aTag.Update()
	If Not IsNull(rsEgenskapstyper.Fields("KORTN_EGENSKAPSTYPE").Value) Then
		set aTag = eAttributt.TaggedValues.AddNew("KORTN_EGENSKAPSTYPE", rsEgenskapstyper.Fields("KORTN_EGENSKAPSTYPE").Value)
		aTag.Update()
	End If
	If Not IsNull(rsEgenskapstyper.Fields("ANTALL_DESIMALER").Value) Then
		set aTag = eAttributt.TaggedValues.AddNew("ANTALL_DESIMALER", rsEgenskapstyper.Fields("ANTALL_DESIMALER").Value)
		aTag.Update()
	End If
	If Not IsNull(rsEgenskapstyper.Fields("TOTAL_FELTLENGDE").Value) Then
		set aTag = eAttributt.TaggedValues.AddNew("TOTAL_FELTLENGDE", rsEgenskapstyper.Fields("TOTAL_FELTLENGDE").Value)
		aTag.Update()
	End If

	If Not IsNull(rsEgenskapstyper.Fields("SOSINVDB_navn").Value) Then set aTag = eAttributt.TaggedValues.AddNew("SOSINVDB_navn", rsEgenskapstyper.Fields("SOSINVDB_navn").Value)
	aTag.Update()
	
	'SOSI-navn - hentes fra Datakatalogen, eller genereres dersom det er blankt.
	If Not IsNull(rsEgenskapstyper.Fields("SOSI_navn").Value) Then '
		set aTag = eAttributt.TaggedValues.AddNew("SOSI_navn", rsEgenskapstyper.Fields("SOSI_navn").Value)
	Else
		set aTag = eAttributt.TaggedValues.AddNew("SOSI_navn", createSOSInavn(rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value, "Lower", 255, ""))
	End If
	aTag.Update()
	If Not IsNull(rsEgenskapstyper.Fields("DATO_FRA").Value) Then set aTag = eAttributt.TaggedValues.AddNew("ObjektlisteFerdigveg", "true")
	aTag.Update()

	If Not IsNull(rsEgenskapstyper.Fields("Viktighet").Value) Then
		Select Case rsEgenskapstyper.Fields("Viktighet").Value
			Case 1 : set aTag = eAttributt.TaggedValues.AddNew("Viktighet", "Påkrevd i database")
			Case 2 : set aTag = eAttributt.TaggedValues.AddNew("Viktighet", "Påkrevd ved nyregistrering")
			Case 3 : set aTag = eAttributt.TaggedValues.AddNew("Viktighet", "Betinget")
			Case 4 : set aTag = eAttributt.TaggedValues.AddNew("Viktighet", "Opsjonell")
			Case 7 : set aTag = eAttributt.TaggedValues.AddNew("Viktighet", "Spesialinfo")
			Case 9 : set aTag = eAttributt.TaggedValues.AddNew("Viktighet", "Historisk")
		End Select
		aTag.Update()
	End If

	If Not IsNull(rsEgenskapstyper.Fields("Sensitivitetskategori").Value) Then
		If rsEgenskapstyper.Fields("Sensitivitetskategori").Value = 1 Then
			set aTag = eAttributt.TaggedValues.AddNew("Sensitiv", "true")
			aTag.Update()
		End If
	End If

	If Not IsNull(rsEgenskapstyper.Fields("navn_enhet").Value) Then
		set aTag = eAttributt.TaggedValues.AddNew("Enhet", rsEgenskapstyper.Fields("navn_enhet").Value)
		aTag.Update()
		'eAttributt.Notes = eAttributt.Notes & vbCrLf & "Enhet: " & rsEgenskapstyper.Fields("navn_enhet").Value
		'eAttributt.Update()
	End If
	
	eAttributt.TaggedValues.Refresh()
End Sub

'Oppdaterer egenskaper (properties) på alle egenskapstyper (attributter) for alle vegobjekttyper (klasser, objekttyper) i EA ut i fra Dakat
function updateEgenskapstyper()
	'Setter opp kobling til modeller og databasetabell
	connect2models
    'Setter opp Recordset som kobles til tabellen EGENSKAPSTYPE i Dakat-databasen
	set rsEgenskapstyper = CreateObject("ADODB.Recordset")
	rsEgenskapstyper.Open "SELECT ENHET.navn_enhet, * FROM ENHET RIGHT JOIN EGENSKAPSTYPE ON ENHET.id_enhet = EGENSKAPSTYPE.ID_ENHET WHERE EGENSKAPSTYPE.NAVN_EGENSKAPSTYPE Not Like 'Utgår%'", dbDakat, 3, 1
	rsEgenskapstyper.Filter = "Dato_fra_nvdb <> NULL AND ID_VEGOB_TYPE <> NULL"

	'Kjører gjennom alle registrerte objekttyper og deres egenskapstyper i EA, pakke for pakke
	'Oppdaterer eksisterende, og sletter utgåtte
	Set lstAlias = CreateObject("System.Collections.ArrayList")
	For idxP = 0 To pkObjekttyper.Packages.Count - 1
		set pkOT_Sub = pkObjekttyper.Packages.GetAt(idxP)
		Repository.WriteOutput "Script", Now & " OPPDATERERER EGENSKAPSTYPER FOR VEGOBJEKTTYPEN " & UCase(pkOT_Sub.Name), 0
		'Filtrerer recordset til aktive egenskapstyper for denne objekttypen
        rsEgenskapstyper.Filter = "Dato_fra_nvdb <> NULL AND ID_VEGOB_TYPE =" & pkOT_Sub.Alias
        'Finner selve vegobjekttypen i pakka
		set element = getElementByAlias(pkOT_Sub, pkOT_Sub.Alias)
        if not element is nothing then
			'Fjerner alle constraints. Disse legges til på nytt fra egenskapstypene
			Repository.WriteOutput "Script", Now & " Fjerner constraints", 0
			For idxT = 0 To element.Constraints.Count - 1
				element.Constraints.DeleteAt idxT, False
			Next 
			'Kjører gjennom alle egenskapstyper under vegobjekttypen i EA. Oppdaterer eksisterende, sletter utgåtte
			For idxA = 0 To element.Attributes.Count - 1
				set eAttributt = element.Attributes.GetAt(idxA)
				'Søker etter egenskapstype med samme id som attributten sitt alias (Style)
				If Not (rsEgenskapstyper.EOF And rsEgenskapstyper.BOF) Then
					rsEgenskapstyper.MoveFirst()
					rsEgenskapstyper.Find("ID_EGENSKAPSTYPE=" & eAttributt.Style)
				End If
				If Not rsEgenskapstyper.EOF Then
					'Oppdaterer egenskapstypen
					Repository.WriteOutput "Script", Now & " Oppdaterer egenskapstype: " & rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value & " (" & rsEgenskapstyper.Fields("ID_EGENSKAPSTYPE").Value & ")",0
					updateProperties_Egenskapstyper()
					lstAlias.Add(eAttributt.Alias)
				Else
					'Egenskapstypen finnes ikke i Dakat, eller skal utgå
					Repository.WriteOutput "Endringer", Now & " Sletter utgått egenskapstype: " & element.Name & "." & eAttributt.Name & " (" & eAttributt.Style & ")",0
					element.Attributes.DeleteAt idxA, False
				End If
			Next 

            'Kjører gjennom alle registrerte egenskapstyper på objekttypen i Dakat, og legger til manglende i EA
            If Not (rsEgenskapstyper.EOF And rsEgenskapstyper.BOF) Then
                rsEgenskapstyper.MoveFirst()
                Do Until rsEgenskapstyper.EOF
					id = cstr(rsEgenskapstyper.Fields("ID_EGENSKAPSTYPE").Value)
                    If Not lstAlias.Contains(id) Then
						'Attributt med angitt alias finnes ikke under objekttypen (dvs i listen over alias)
						Repository.WriteOutput "Endringer", Now & " Lager egenskapstype: " & element.Name & "." & rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value & " (" & rsEgenskapstyper.Fields("ID_EGENSKAPSTYPE").Value & ")",0
						set eAttributt = element.Attributes.AddNew(rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value, "")
						eAttributt.Update()
						updateProperties_Egenskapstyper()
                    Else
                        Repository.WriteOutput "Script", Now & " Egenskapstypen finnes: " & rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value & " (" & rsEgenskapstyper.Fields("ID_EGENSKAPSTYPE").Value & ")",0
                    End If
                    rsEgenskapstyper.MoveNext()
                Loop
            End If			
		end if
	Next

    Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"

end function


