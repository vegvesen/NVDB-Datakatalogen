option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre


Sub updateProperties_Kodelister()
	'Oppdaterer kodelister (ikke verdier)
	element.Name = rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value
	If Not IsNull(rsEgenskapstyper.Fields("BSKR_EGENSKAPSTYPE").Value) Then element.Notes = rsEgenskapstyper.Fields("BSKR_EGENSKAPSTYPE").Value
	element.StereotypeEx = ""
	element.Stereotype = "Tillatte verdier"
	element.Alias = rsEgenskapstyper.Fields("ID_EGENSKAPSTYPE").Value
	element.Status = "Implemented"
	element.Visibility = "Public"
	element.Author = "Dakat"
	element.Version = FC_version
	element.Modified = Now
	element.Update()
	'Fjerner alle tagged values og legger til p� nytt
	For idxT = 0 To element.TaggedValues.Count - 1
		element.TaggedValues.DeleteAt idxT, False
	Next
	set tagVal = element.TaggedValues.AddNew("ID_EGENSKAPSTYPE", rsEgenskapstyper.Fields("ID_EGENSKAPSTYPE").Value)
	tagVal.Update()
	set tagVal= element.TaggedValues.AddNew("NAVN_EGENSKAPSTYPE", rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value)
	tagVal.Update()

	If Not IsNull(rsEgenskapstyper.Fields("DATO_FRA").Value) Then set tagVal = element.TaggedValues.AddNew("ObjektlisteFerdigveg", "true")
	tagVal.Update()

	Select Case rsEgenskapstyper.Fields("ID_DATATYPE").Value
		Case 30
			set tagVal= element.TaggedValues.AddNew("SOSI_datatype", "T")
		Case 31
			'MsgBox("31")
			If Not IsNull(rsEgenskapstyper.Fields("ANTALL_DESIMALER").Value) Then
				If rsEgenskapstyper.Fields("ANTALL_DESIMALER").Value = 0 Then
					set tagVal = element.TaggedValues.AddNew("SOSI_datatype", "H")
				Else
					set tagVal = element.TaggedValues.AddNew("SOSI_datatype", "D")
				End If
			Else
				set tagVal = element.TaggedValues.AddNew("SOSI_datatype", "H")
			End If
	End Select
	tagVal.Update()

	If Not IsNull(rsEgenskapstyper.Fields("KORTN_EGENSKAPSTYPE").Value) Then
		set tagVal = element.TaggedValues.AddNew("KORTN_EGENSKAPSTYPE", rsEgenskapstyper.Fields("KORTN_EGENSKAPSTYPE").Value)
		tagVal.Update()
	End If
	If Not IsNull(rsEgenskapstyper.Fields("TOTAL_FELTLENGDE").Value) Then
		set tagVal = element.TaggedValues.AddNew("TOTAL_FELTLENGDE", rsEgenskapstyper.Fields("TOTAL_FELTLENGDE").Value)
		tagVal.Update()
	End If
	If Not IsNull(rsEgenskapstyper.Fields("ANTALL_DESIMALER").Value) Then
		set tagVal = element.TaggedValues.AddNew("ANTALL_DESIMALER", rsEgenskapstyper.Fields("ANTALL_DESIMALER").Value)
		tagVal.Update()
	End If

	set tagVal = element.TaggedValues.AddNew("SOSINVDB_navn", rsEgenskapstyper.Fields("SOSINVDB_navn").Value)
	tagVal.Update()
	'SOSI-navn - skal v�re unikt. Hentes fra tilh�rende egenskap i modellen 
	Dim el as EA.Element
	For Each el In pkOT_Sub.Elements
		'S�ker gjennom pakka for � finne selve objekttypen og den egenskapen kodelista tilh�rer
		If el.Stereotype = "Vegobjekttype" Then
			'finner SOSI-navn for objekttypen, til bruk som eventuell suffix. For eksempel: "Basseng/Magasin" => "BassengMagasin"
			set tagVal = el.TaggedValues.GetByName("SOSI_navn")
			Dim strSOSI_OT 
			strSOSI_OT = tagVal.Value
			dim attr as EA.Attribute
			For Each attr In el.Attributes
				'Finner attributten som kodelisten tilh�rer
				If attr.Style = element.Alias Then
					'finner SOSI-navn for attributten
					set aTag = attr.TaggedValues.GetByName("SOSI_navn")
					If not aTag is Nothing then
						'Lager s� velformulert og unikt SOSI-navn, med suffix dersom det er n�dvendig for � f� det unikt i SOSI. For eksempel: "Eier" => "EierBassengMagasin"
						Dim strSOSInavn
						strSOSInavn = UCase(Left(aTag.Value, 1)) &  Mid(aTag.Value, 2)
						'Kontrollerer i  om det nye navnet er i bruk p� andre kodelister i Datakatalogen, og legger i s�fall p� suffix
						'For eksempel: "Eier" kan v�re unikt i SOSI Objektkatalog, men det kan v�re andre egenskaper i Datakatalog-modellen som har samme SOSI-tag.
						If lstCodeListNames.Contains(strSOSInavn) Then
							strSOSInavn = strSOSInavn & strSOSI_OT
						End if
						Repository.WriteOutput "SOSI", Now & " SOSI-navn for " & element.Name & ": " & strSOSInavn, 0 
						set tagVal = element.TaggedValues.AddNew("SOSI_navn", strSOSInavn)
						lstCodeListNames.Add(strSOSInavn)
					end if
				End If
			Next
		End If
	Next
	tagVal.Update()

	If rsEgenskapstyper.Fields("kortnavn_TV_offisiell").Value = True Then
		set tagVal = element.TaggedValues.AddNew("kortnavn_TV_offisiell", "True")
	Else
		set tagVal = element.TaggedValues.AddNew("kortnavn_TV_offisiell", "False")
	End If
	element.TaggedValues.Refresh()

End Sub


'Oppdaterer kodelister (lister med tillatte verdier)
sub updateKodelister()
	'Setter opp sp�rring som viser egenskaper med tillatte verdier i Dakat-databasen
	connect2models
	set rsEgenskapstyper = CreateObject("ADODB.Recordset")
	rsEgenskapstyper.Open "SELECT DISTINCT EGENSKAPSTYPE.* FROM EGENSKAPSTYPE INNER JOIN TILLATT_VERDI ON EGENSKAPSTYPE.ID_EGENSKAPSTYPE = TILLATT_VERDI.ID_EGENSKAPSTYPE WHERE NAVN_EGENSKAPSTYPE NOT LIKE 'Utg�r%'", dbDakat, 3, 1
    rsEgenskapstyper.Filter = "Dato_fra_nvdb <> NULL AND ID_VEGOB_TYPE <> NULL"
   
	rsEgenskapstyper.MoveLast()
    Repository.WriteOutput "Script", Now & " Oppdaterer kodelister og legger til nye", 0 
	Set lstCodeListNames = CreateObject("System.Collections.ArrayList")
	'Kj�r gjennom alle pakker, finn alle vegobjekttyper sine SOSI-navn og legg til i listen
	Repository.WriteOutput "Script", Now & " Lager liste med brukte SOSI-navn",0
	For each pkOT_Sub in pkObjekttyper.Packages
		For each element in pkOT_Sub.elements
			If element.Stereotype = "Vegobjekttype" then
			   set  tagVal = element.TaggedValues.GetByName("SOSI_navn")
			   if not tagVal is Nothing then
				lstCodeListNames.Add tagVal.Value
				Repository.WriteOutput "Script", Now & " Legger til vegobjekttype " & pkOT_Sub.Name & " med SOSI-navn " & tagVal.Value & " i liste",0
			   end if
			end if
		Next
	Next
	
	For idxP = 0 To pkObjekttyper.Packages.Count - 1
		Set lstAlias = CreateObject("System.Collections.ArrayList")
		set pkOT_Sub = pkObjekttyper.Packages.GetAt(idxP)
		id = pkOT_Sub.Alias
		rsEgenskapstyper.Filter = "Dato_fra_nvdb <> NULL AND ID_VEGOB_TYPE =" & pkOT_Sub.Alias
		Repository.WriteOutput "Script", Now & " OPPDATERER KODELISTER FOR VEGOBJEKTTYPEN " & UCase(pkOT_Sub.Name),0
		
		'L�kke for kodelister i pakka
		For idxE = 0 To pkOT_Sub.Elements.Count - 1
			set element = pkOT_Sub.Elements.GetAt(idxE)
			If element.Stereotype = "Tillatte verdier" Then
				'Tester om egenskapstypen finnes med tillatte verdier i Dakat
				If Not (rsEgenskapstyper.EOF And rsEgenskapstyper.BOF) Then
					rsEgenskapstyper.MoveFirst()
					rsEgenskapstyper.Find("ID_EGENSKAPSTYPE=" & element.Alias)
				End If
				If Not rsEgenskapstyper.EOF Then
					'Oppdaterer egenskapstypen
					Repository.WriteOutput "Script", Now & " Oppdaterer kodeliste: " & rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value & " (" & rsEgenskapstyper.Fields("ID_EGENSKAPSTYPE").Value & ")",0
					updateProperties_Kodelister()
					lstAlias.Add(element.Alias)
				Else
					'Egenskapstypen finnes ikke med tillatte verdier i Dakat
					Repository.WriteOutput "Endringer", Now & " Sletter utg�tt kodeliste: " & pkOT_Sub.Name & "." & element.Name & " (" & element.Alias & ")",0
					pkOT_Sub.Elements.DeleteAt idxE, False
				End If
			End If
		Next 
		pkOT_Sub.Elements.Refresh()

		'Kj�rer gjennom alle registrerte egenskapstyper med tillatte verdier p� objekttypen i Dakat, og legger til manglende i EA
		If Not (rsEgenskapstyper.EOF And rsEgenskapstyper.BOF) Then
			rsEgenskapstyper.MoveFirst()
			Do Until rsEgenskapstyper.EOF
				id = cstr(rsEgenskapstyper.Fields("ID_EGENSKAPSTYPE").Value	)
				If Not lstAlias.Contains(id) Then
					'Kodelisten finnes ikke 
					Repository.WriteOutput "Endringer", Now & " Lager kodeliste: " & pkOT_Sub.Name & "." & rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value & " (" & rsEgenskapstyper.Fields("ID_EGENSKAPSTYPE").Value & ")",0
					set element = pkOT_Sub.Elements.AddNew(rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value, "Class")
					element.Update()
					updateProperties_Kodelister()
				Else
					Repository.WriteOutput "Script", Now & " Kodelisten finnes: " & rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value & " (" & rsEgenskapstyper.Fields("ID_EGENSKAPSTYPE").Value & ")",0
				End If
				rsEgenskapstyper.MoveNext()
			Loop
		End If
		
		'Sorterer objekter (featuretype og codelists) i pakka
		sortElementsInPackage(pkOT_Sub)
		
	Next

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"

end sub

updateKodelister
