option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre


' Denne filen inneholder funksjoner for oppdatering av kodelister (lister med tillatte verdier) for vegobjekttyper i EA-prosjektet. 
'
' Script Name: NVDB til UML.Kodelister
' Author: Knut Jetlund
' Purpose: Oppdatering av lister med tillatte verdier
' Date: 20220919
'
' **************************************************************

'Oppdaterer klassen for en kodeliste i EA ut i fra Dakat. Kun klassen, ikke verdier.

function updateProperties_Kodelister()
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
	'Fjerner alle tagged values og legger til på nytt
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

	'If Not IsNull(rsEgenskapstyper.Fields("SOSI_navn").Value) Then '
	'	set tagVal = element.TaggedValues.AddNew("SOSI_navn", rsEgenskapstyper.Fields("SOSI_navn").Value)
	'Else
	'	set tagVal = element.TaggedValues.AddNew("SOSI_navn", createSOSInavn(rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value, "Upper", 255, ""))
	'End If
	'tagVal.Update()
	
	'SOSI-navn - skal være unikt. Hentes fra tilhørende egenskap i modellen 
	Dim el as EA.Element
	For Each el In pkOT_Sub.Elements
		'Søker gjennom pakka for å finne selve objekttypen og den egenskapen kodelista tilhører
		If el.Stereotype = "Vegobjekttype" Then
			'finner SOSI-navn for objekttypen, til bruk som eventuell suffix. For eksempel: "Basseng/Magasin" => "BassengMagasin"
			set tagVal = el.TaggedValues.GetByName("SOSI_navn")		
			
			Dim strSOSI_OT 
			strSOSI_OT = tagVal.Value
			dim attr as EA.Attribute
			
			For Each attr In el.Attributes
				'Finner attributten som kodelisten tilhører
				If attr.Style = element.Alias Then
					'finner SOSI-navn for attributten
					set aTag = attr.TaggedValues.GetByName("SOSI_navn")
					
					If not aTag is Nothing then
						'Lager så velformulert og unikt SOSI-navn, med suffix dersom det er nødvendig for å få det unikt i SOSI. For eksempel: "Eier" => "EierBassengMagasin"
						Dim strSOSInavn
						strSOSInavn = UCase(Left(aTag.Value, 1)) &  Mid(aTag.Value, 2)
						'Kontrollerer i  om det nye navnet er i bruk på andre kodelister i Datakatalogen, og legger i såfall på suffix
						'For eksempel: "Eier" kan være unikt i SOSI Objektkatalog, men det kan være andre egenskaper i Datakatalog-modellen som har samme SOSI-tag.
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

End function

'Oppdaterer kodelisteklasser for alle vegobjekttyper i EA ut i fra Dakat. Kun klassene, ikke verdier
function updateKodelister()
	'Setter opp spørring som viser aktive egenskaper med tillatte verdier i Dakat-databasen
	connect2models
	set rsEgenskapstyper = CreateObject("ADODB.Recordset")
	rsEgenskapstyper.Open "SELECT DISTINCT EGENSKAPSTYPE.* FROM EGENSKAPSTYPE INNER JOIN TILLATT_VERDI ON EGENSKAPSTYPE.ID_EGENSKAPSTYPE = TILLATT_VERDI.ID_EGENSKAPSTYPE WHERE NAVN_EGENSKAPSTYPE NOT LIKE 'Utgår%'", dbDakat, 3, 1
    rsEgenskapstyper.Filter = "Dato_fra_nvdb <> NULL AND ID_VEGOB_TYPE <> NULL"
   
	rsEgenskapstyper.MoveLast()
    Repository.WriteOutput "Script", Now & " Oppdaterer kodelister og legger til nye", 0 
	Set lstCodeListNames = CreateObject("System.Collections.ArrayList")
	'Kjør gjennom alle pakker, finn alle vegobjekttyper sine SOSI-navn og legg til i liste med brukte SOSI-navn.
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
	
	'Kjør gjennom SOSI Fellesegenskaper, finn alle kodelister og legg til navnet i listen med brukte SOSI-navn
	For each element in pkSOSIFelles.elements
		If UCase(element.Stereotype) = "CODELIST" then
			lstCodeListNames.Add element.Name
			Repository.WriteOutput "Script", Now & " Legger til SOSI-kodeliste " & element.Name & " i liste",0
		end if
	Next
	
	For idxP = 0 To pkObjekttyper.Packages.Count - 1
		Set lstAlias = CreateObject("System.Collections.ArrayList")
		set pkOT_Sub = pkObjekttyper.Packages.GetAt(idxP)
		id = pkOT_Sub.Alias
		rsEgenskapstyper.Filter = "Dato_fra_nvdb <> NULL AND ID_VEGOB_TYPE =" & pkOT_Sub.Alias
		Repository.WriteOutput "Script", Now & " OPPDATERER KODELISTER FOR VEGOBJEKTTYPEN " & UCase(pkOT_Sub.Name),0
		
		'Kjører gjennom alle registrerte kodelister for denne pakken i EA, og sammenligner med Dakat
		dim count
		count = pkOT_Sub.Elements.Count - 1
		For idxE = 0 To count step 1
			if idxE > count then
				exit for
			end if
			set element = pkOT_Sub.Elements.GetAt(idxE)
			If element.Stereotype = "Tillatte verdier" Then
				'Tester om egenskapstypen finnes og har tillatte verdier i Dakat
				'NB! Dakat har ikke kodelister, kun tillatte verdier knytta til egenskapstyper. Sjekker derfor om egenskapstypen finnes. 
				If Not (rsEgenskapstyper.EOF And rsEgenskapstyper.BOF) Then
					rsEgenskapstyper.MoveFirst()
					rsEgenskapstyper.Find("ID_EGENSKAPSTYPE=" & element.Alias)
				End If
				If Not rsEgenskapstyper.EOF Then
					'Egenskapstypen finnes og har tillatte verdier i Dakat --> Oppdaterer kodelisteklassen
					Repository.WriteOutput "Script", Now & " Oppdaterer kodeliste: " & rsEgenskapstyper.Fields("NAVN_EGENSKAPSTYPE").Value & " (" & rsEgenskapstyper.Fields("ID_EGENSKAPSTYPE").Value & ")",0
					updateProperties_Kodelister()
					lstAlias.Add(element.Alias)
				Else
					'Egenskapstypen finnes ikke med tillatte verdier i Dakat --> Slett kodelisteklassen
					Repository.WriteOutput "Endringer", Now & " Sletter utgått kodeliste: " & pkOT_Sub.Name & "." & element.Name & " (" & element.Alias & ")",0
					pkOT_Sub.Elements.DeleteAt idxE, true				
					idxE = idxE - 1
					count = count - 1
				End If
			End If
		Next 
		pkOT_Sub.Elements.Refresh()

		'Kjører gjennom alle registrerte egenskapstyper med tillatte verdier på objekttypen i Dakat, og legger til manglende i EA
		If Not (rsEgenskapstyper.EOF And rsEgenskapstyper.BOF) Then
			rsEgenskapstyper.MoveFirst()
			Do Until rsEgenskapstyper.EOF
				id = cstr(rsEgenskapstyper.Fields("ID_EGENSKAPSTYPE").Value	)
				If Not lstAlias.Contains(id) Then
					'Kodelisten finnes ikke i EA. Legger til kodelisteklassen.
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
		
		'Sorterer objekter (featuretype og codelists) i pakka i samsvar med sortering i Dakat
		sortElementsInPackage(pkOT_Sub)
		
	Next

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"

end function


