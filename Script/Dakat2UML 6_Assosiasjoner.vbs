option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre


Sub updateProperties_Assosiasjoner()
	'Oppdaterer egenskaper på en assosiasjon i EA ut i fra Dakat
	'Type assosiasjon
	Dim sr, dr, Contype, subtype 
	Dim min, maks, sourceCard, destCard
	subtype = ""
	Select Case rsSammenhenger.Fields("ID_SAMMENHENGTYPE").Value
		Case 1
			sr = "Består av"
			dr = "Er del av"
			Contype = "Aggregation"
			subtype = "Strong"
			destCard = "0..1"
		Case 2
			sr = "Har"
			dr = "Tilhører"
			Contype = "Aggregation"
			destCard = "0..1"
		Case 3
			sr = "Har tilkoplet"
			dr = "Er tilkoplet til"
			Contype = "Association"
			destCard = "0..1"
		Case 6
			sr = "Starter i"
			dr = "Er start for"
			Contype = "Association"
			destCard = "0..1"
		Case 7
			sr = "Slutter i"
			dr = "Er slutt for"
			Contype = "Association"
			destCard = "0..1"
		Case 13
			sr = "Lokaliserer"
			dr = "Er lokalisert i"
			Contype = "Association"
			destCard = "0..1"
		Case Else
			sr = " "
			dr = " "
			Contype = " "
			destCard = "0..*"
	End Select

	'Kardinalitet
	If IsNull(rsSammenhenger.Fields("Min_antall").Value) Then
		min = 0
	Else
		min = rsSammenhenger.Fields("Min_antall").Value
	End If
	maks = rsSammenhenger.Fields("Maks_antall").Value
	If maks >= 99999 Then
		sourceCard = min & "..*"
	Else
		sourceCard = min & ".." & maks
	End If

	con.Type = Contype
	con.Direction = "Destination -> Source"
	con.Subtype = subtype
	con.SupplierID = elementA.ElementID

	'Angi kardinaliteter
	Dim client As EA.ConnectorEnd
	set client = con.ClientEnd
	client.Visibility = "Public"
	client.Role = sr
	client.Cardinality = sourceCard
	'client.update

	Dim supplier As EA.ConnectorEnd
	set supplier = con.SupplierEnd
	supplier.Visibility = "Public"
	supplier.Role = dr
	supplier.Cardinality = destCard
	'supplier.update
	con.Update()
	elementB.Connectors.Refresh()

	'Fjerner alle tagged values og legger til på nytt
	For idxT = 0 To con.TaggedValues.Count - 1
		con.TaggedValues.DeleteAt idxT, False
	Next 
	Dim cTag As EA.ConnectorTag
	set cTag = con.TaggedValues.AddNew("NVDB_ID", rsSammenhenger.Fields("ID_TILLATT_SAMMENHENG").Value)
	cTag.Update()
	con.TaggedValues.Refresh()
	Repository.WriteOutput "Script", Now & " Assosiasjonsdetaljer: " & supplier.Role & " [" & supplier.Cardinality & "] - " & client.Role & " [" & client.Cardinality & "]",0
End Sub


sub updateAssosiasjoner()
'Oppdatering av assosiasjoner
	connect2models
	set rsSammenhenger = CreateObject("ADODB.Recordset")
	rsSammenhenger.Open "SELECT TILLATT_SAMMENHENG.* FROM VEGOB_TYPE INNER JOIN TILLATT_SAMMENHENG ON VEGOB_TYPE.ID_VOBJ_TYPE = TILLATT_SAMMENHENG.VOBJ_TYP_B WHERE VEGOB_TYPE.Dato_fra_nvdb Is Not Null", dbDakat, 3, 1
    rsSammenhenger.Filter = "Dato_fra_nvdb <> NULL"
    rsSammenhenger.MoveLast()
    Repository.WriteOutput "Script", Now & " Oppdaterer assosiasjoner. Fjerner utgåtte og legger til nye", 0 

	'Kjører gjennom alle registrerte objekttyper i EA. Oppdaterer eksisterende assosiasjoner, sletter utgåtte
	For idxP = 0 To pkObjekttyper.Packages.Count - 1
		set pkOT_Sub = pkObjekttyper.Packages.GetAt(idxP)
		Set lstAlias = CreateObject("System.Collections.ArrayList")
		rsSammenhenger.Filter = "Dato_fra_nvdb <> NULL AND VOBJ_TYP_A =" & pkOT_Sub.Alias
        'Finner selve objekttypen i pakka
		set elementA = getElementByAlias(pkOT_Sub, pkOT_Sub.Alias)
        if not elementA is nothing then
            Repository.WriteOutput "Script", Now & " OPPDATERER ASSOSIASJONER FOR VEGOBJEKTTYPEN " & UCase(elementA.Name),0
			'Løkke for assosiasjoner på objekttypen
			For idxC = 0 To elementA.Connectors.Count - 1
				set con = elementA.Connectors.GetAt(idxC)
				'Tar kun med de assosiasjonene der aktuelt element er "Supplier"
				If con.SupplierID = elementA.ElementID And con.Type <> "NoteLink" Then
					'Finner objekttypen i den andre enden
					set elementB = Repository.GetElementByID(con.ClientID)
					If Not (rsSammenhenger.EOF And rsSammenhenger.BOF) Then
						rsSammenhenger.MoveFirst()
						rsSammenhenger.Find("VOBJ_TYP_B=" & elementB.Alias)
					End If
					If Not rsSammenhenger.EOF Then
						'Oppdaterer assosiasjonen
						Repository.WriteOutput "Script", Now & " Oppdaterer assosiasjon til: " & elementB.Name,0
						updateProperties_Assosiasjoner()
						lstAlias.Add(elementB.Alias)
					Else
						'Assosiasjonen finnes ikke, sletter
						Repository.WriteOutput "Endringer", Now & " Sletter utgått assosiasjon fra " & elementA.Name & " til: " & elementB.Name, 0
						elementA.Connectors.DeleteAt idxC, False
					End If
				End If
			Next 
			elementA.Connectors.Refresh()

            'Kjører gjennom alle registrerte sammenhenger for objekttypen i Dakat, og legger til manglende i EA
            If Not (rsSammenhenger.EOF And rsSammenhenger.BOF) Then
                rsSammenhenger.MoveFirst()
                Do Until rsSammenhenger.EOF
					id = cstr(rsSammenhenger.Fields("VOBJ_TYP_B").Value)
					If Not lstAlias.Contains(id) Then
						Repository.WriteOutput "Script", Now & " Assosiasjonen mangler: " & elementA.Name & " - Vegobjekttype " & rsSammenhenger.Fields("VOBJ_TYP_B").Value,0
						set elementB = Nothing
						'Assosiasjon til objekt med angitt alias finnes ikke på den aktuelle objekttypen
						'Finner element B for den aktuelle sammenhengen
						dim locPck as EA.Package
						dim locPidx
						For locPidx = 0 To pkObjekttyper.Packages.Count - 1
							set locPck = pkObjekttyper.Packages.GetAt(locPidx)
							'Repository.WriteOutput "Endringer", Now & " Søk etter pakke for ny assosiasjon fra " & elementA.Name & " : " & locPck.Name & " (" & locPck.Alias & ")",0
							If locPck.Alias = id Then
								'Repository.WriteOutput "Endringer", Now & " Funnet pakke for ny assosiasjon fra " & elementA.Name & " : " & locPck.Name & " (" & locPck.Alias & ")",0
								set elementB = getElementByAlias(locPck, cstr(rsSammenhenger.Fields("VOBJ_TYP_B").Value))
								locPidx = pkObjekttyper.Packages.Count - 1
							End If
						Next
						if not elementB is nothing then
							Repository.WriteOutput "Endringer", Now & " Lager ny assosiasjon fra " & elementA.Name & " til: " & elementB.Name,0
							set con = elementB.Connectors.AddNew("", "Association")
							updateProperties_Assosiasjoner()
						Else
							Repository.WriteOutput "Error", Now & " Angitt assosiert objekttype finnes ikke: " & rsSammenhenger.Fields("VOBJ_TYP_B").Value, 0
						End If
                    Else
                        Repository.WriteOutput "Script", Now & " Assosiasjonen finnes: " & elementA.Name & " - Vegobjekttype " & rsSammenhenger.Fields("VOBJ_TYP_B").Value,0
                    End If
                    rsSammenhenger.MoveNext()
                Loop
            End If
		end if
	next

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"

end sub

updateAssosiasjoner
