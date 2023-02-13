option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre


' Denne filen inneholder funksjoner for oppdatering av kodelisteverdier (tillatte verdier) for vegobjekttyper i EA-prosjektet. 
'
' Script Name: NVDB til UML.Kodelisteverdier
' Author: Knut Jetlund
' Purpose: Oppdatering av tillatte verdier
' Date: 20220919
'
' **************************************************************

'Oppdaterer egenskaper på en enkelt kodelisteverdi i EA ut i fra Dakat
Sub updateProperties_Kodelisteverdier()
	eAttributt.Name = rsKodelister.Fields("NAVN_TILLATT_VERDI").Value
	eAttributt.Visibility = "Public"
	eAttributt.Style = rsKodelister.Fields("ID_TILLATT_VERDI").Value
	If Not IsNull(rsKodelister.Fields("BSKR_TILLATT_VERDI").Value) Then 
		eAttributt.Notes = rsKodelister.Fields("BSKR_TILLATT_VERDI").Value
	else
		eAttributt.Notes = rsKodelister.Fields("NAVN_TILLATT_VERDI").Value
	end if
	dim offKV
	If Not IsNull(rsKodelister.Fields("KORTN_TILLATT_VERDI").Value) And rsKodelister.Fields("kortnavn_TV_offisiell").Value = True Then
		offKV = true
		eAttributt.Default = rsKodelister.Fields("KORTN_TILLATT_VERDI").Value
	Else
		offKV = false
		eAttributt.Default = ""
	End If
	If Not IsNull(rsKodelister.Fields("NR_TILLATT_VERDI").Value) Then eAttributt.Pos = rsKodelister.Fields("NR_TILLATT_VERDI").Value
	eAttributt.Update()

	'Fjerner alle tagged values og legger til på nytt
	For idxT = 0 To eAttributt.TaggedValues.Count - 1
		eAttributt.TaggedValues.DeleteAt idxT, False
	Next 
	set aTag = eAttributt.TaggedValues.AddNew("ID_TILLATT_VERDI", rsKodelister.Fields("ID_TILLATT_VERDI").Value)
	aTag.Update()
	set aTag = eAttributt.TaggedValues.AddNew("NAVN_TILLATT_VERDI", rsKodelister.Fields("NAVN_TILLATT_VERDI").Value)
	aTag.Update()
	If Not IsNull(rsKodelister.Fields("KORTN_TILLATT_VERDI").Value) Then 
		set aTag = eAttributt.TaggedValues.AddNew("KORTN_TILLATT_VERDI", rsKodelister.Fields("KORTN_TILLATT_VERDI").Value)
		aTag.Update()
	end if	
	If offKV Then
		set aTag = eAttributt.TaggedValues.AddNew("Offisell kortverdi", "true")
	end if 

	If Not IsNull(rsKodelister.Fields("SOSI_navn").Value) Then '
		set aTag = eAttributt.TaggedValues.AddNew("SOSI_navn", rsKodelister.Fields("SOSI_navn").Value)
	'Else
	'	set aTag = eAttributt.TaggedValues.AddNew("SOSI_navn", createSOSInavn(rsKodelister.Fields("NAVN_TILLATT_VERDI").Value, "Lower", 255, ""))
	End If
	aTag.Update()

	eAttributt.TaggedValues.Refresh()
End Sub


'Oppdaterer alle kodelisteverdier (tillatte verdier) for alle vegobjekttyper
function updateKodelisteverdier()
	'Setter opp spørring som viser alle aktive tillatte verdier i Dakat-databasen
	connect2models
	set rsKodelister = CreateObject("ADODB.Recordset")
	rsKodelister.Open "SELECT TILLATT_VERDI.*, EGENSKAPSTYPE.kortnavn_TV_offisiell FROM TILLATT_VERDI INNER JOIN EGENSKAPSTYPE ON TILLATT_VERDI.ID_EGENSKAPSTYPE = EGENSKAPSTYPE.ID_EGENSKAPSTYPE WHERE NAVN_TILLATT_VERDI NOT LIKE 'Utgår%'", dbDakat, 3, 1
   	rsKodelister.MoveLast()
    Repository.WriteOutput "Script", Now & " Oppdaterer kodelisteverdier og legger til nye", 0 
	
	For idxP = 0 To pkObjekttyper.Packages.Count - 1
		set pkOT_Sub = pkObjekttyper.Packages.GetAt(idxP)
		id = pkOT_Sub.Alias
		Repository.WriteOutput "Script", Now & " OPPDATERER KODELISTEVERDIER FOR VEGOBJEKTTYPEN " & UCase(pkOT_Sub.Name),0
		
		'Kjører gjennom alle pakker og kodelister 
		For idxE = 0 To pkOT_Sub.Elements.Count - 1
			set element = pkOT_Sub.Elements.GetAt(idxE)
			If element.Stereotype = "Tillatte verdier" Then
				Set lstAlias = CreateObject("System.Collections.ArrayList")
                rsKodelister.Filter = "Dato_fra_nvdb <> NULL AND ID_EGENSKAPSTYPE =" & element.Alias
				Repository.WriteOutput "Script", Now & " KODELISTE: " & UCase(element.Name),0
				'Kjører gjennom alle kodelisteverdier for denne pakka
				For idxA = 0 To element.Attributes.Count - 1
					set eAttributt = element.Attributes.GetAt(idxA)
					'Tester om kodelisteverdien finnes i Dakat, vha alias (Style)
					If Not (rsKodelister.EOF And rsKodelister.BOF) Then
						rsKodelister.MoveFirst()
						rsKodelister.Find("ID_TILLATT_VERDI=" & eAttributt.Style)
					End If
					If Not rsKodelister.EOF Then
						'Verdien finnes i Dakat --> Oppdaterer egenskaper for verdien
						Repository.WriteOutput "Script", Now & " Oppdaterer tillatt verdi: " & rsKodelister.Fields("NAVN_TILLATT_VERDI").Value & " (" & rsKodelister.Fields("ID_TILLATT_VERDI").Value & ")",0
						lstAlias.Add(eAttributt.Style)
						updateProperties_Kodelisteverdier()
					Else
						'Verdien finnes ikke i Dakat --> Slettes
						Repository.WriteOutput "Endringer", Now & " Sletter utgått verdi: " & pkOT_Sub.Name & "." & element.Name & "." & eAttributt.Name & " (" & eAttributt.Style & ")",0
						element.Attributes.DeleteAt idxA, False
					End If
				Next 				
			
				'Kjører gjennom alle registrerte tillatte verdier på egenskapstypen i Dakat, og legger til manglende i EA
				If Not (rsKodelister.EOF And rsKodelister.BOF) Then
					rsKodelister.MoveFirst()
					Do Until rsKodelister.EOF
						id = cstr(rsKodelister.Fields("ID_TILLATT_VERDI").Value)
						If Not lstAlias.Contains(id) Then
							'Tillatt verdi finnes ikke, legger til kodelisteverdi i kodelisten
							Repository.WriteOutput "Endringer", Now & " Legger til tillatt verdi: " & pkOT_Sub.Name & "." & element.Name & "." & rsKodelister.Fields("NAVN_TILLATT_VERDI").Value & " (" & rsKodelister.Fields("ID_TILLATT_VERDI").Value & ")",0
							set eAttributt = element.Attributes.AddNew(rsKodelister.Fields("NAVN_TILLATT_VERDI").Value, "")
							eAttributt.Update()
							updateProperties_Kodelisteverdier()
						Else
							Repository.WriteOutput "Script", Now & " Kodelisteverdien finnes: " & element.Name & "." & rsKodelister.Fields("NAVN_TILLATT_VERDI").Value,0
						End If
						rsKodelister.MoveNext()
					Loop
				End If
			End If
		Next 
	Next
	
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"

end function

