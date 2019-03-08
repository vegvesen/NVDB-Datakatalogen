option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

' Script Name: DakatUML2SOSI_0_Felles
' Author: Knut Jetlund
' Purpose: Fellesfunksjoner for konvertering fra Datakatlog-UML til SOSI-Modellregister
' Date: 2019-03-08
'

Dim strAlias
Dim strStedfesting 
Dim retning 
Dim kjorefelt 

sub updateClassProperties()
'Oppdaterer properties for klasser (objekttyper og kodelister)
	if elNVDB.stereotype = "Vegobjekttype" then 
		element.stereotype = "featureType"
	ElseIf elNVDB.stereotype = "Tillatte verdier" then 
		element.stereotype = "CodeList" 
	End if 
	element.Notes = elNVDB.Notes
	element.Version = FC_version
	element.Update	
	'Fjerner alle tagged values på feature typen og legger til på nytt
	For idxT = 0 To element.TaggedValues.Count - 1
		element.TaggedValues.DeleteAt idxT, False
	Next	
	
	'Defaultverdier
	strAlias = "Ikke angitt"
	strStedfesting = "punkt"
	retning = False
	kjorefelt = 0
	
	dim newTV as EA.TaggedValue
	'Kjører gjennom alle tagged values på NVDB-pakken og overfører informasjon
	For idxT = 0 To elNVDB.TaggedValues.Count - 1
		set tagVal = elNVDB.TaggedValues.GetAt(idxT)
		Select Case tagVal.Name
			Case "SOSI_navn"
				'SOSI-navn på objekttypen. Brukes for å sette SOSI-modellnavn og SOSI-formatnavn
				Repository.WriteOutput "SOSI", Now & " Klassen " & element.Name & " (" & element.Alias & ") oppdateres til " & element.Stereotype & " " & tagVal.Value,0
				'Endrer navn på klassen til SOSI-modellnavn
				element.Name = tagVal.Value
				'Lager ny tagged value på SOSI-elementet for SOSI-formatnavn (NVDB_ & Uppercase(element.Name))
				'Unntak: De som allerede har prefix "NVDB_" skal kun ha uppercase, ikke ny prefix
				set newTV = element.TaggedValues.AddNew("SOSI_navn", "")
				If Not Mid(element.Name, 1, 5) = "NVDB_" Then
					newTV.Value = "NVDB_" & Ucase(tagVal.Value)
				Else
					newTV.Value = Ucase(tagVal.Value)
				End If
				newTV.Update()
			Case "Stedfesting"
				'Stedfesting (strekning eller punkt). Henter informasjonen til senere bruk (kun vegobjekttyper)
				strStedfesting = tagVal.Value
				Repository.WriteOutput "SOSI", Now & " Stedfesting: " & tagVal.Value,0
			Case "RetningsRelevant"
				'Retning relevant. Henter informasjonen til senere bruk (kun vegobjekttyper)
				Repository.WriteOutput "SOSI", Now & " Skal ha retning: " & tagVal.Value,0
				If tagVal.Value = "true" Then retning = True
			Case "KjorefeltRelevant"
				'Retning relevant. Henter informasjonen til senere bruk (kun vegobjekttyper)
				Repository.WriteOutput "SOSI", Now & " Skal/kan ha kjorefelt: " & tagVal.Value,0
				kjorefelt = tagVal.Value
			Case "SOSI_datatype"
				'NVDB-datatype - konverteres til SOSI-datatype (kun kodelister)

			Case "TOTAL_FELTLENGDE"
				'Feltlengde - tas vare på for SOSI-realisering (kun kodelister)
				set newTV = element.TaggedValues.AddNew("SOSI_lengde", "tagVal.Value")
				newTV.Update()
		End Select
	Next	

	'Lager tagged values direkte fra navn og alias
	set newTV = element.TaggedValues.AddNew("catalogue-entry", "NVDB Datakatalogen")
	newTV.Update()
	set newTV = element.TaggedValues.AddNew("NVDB_ID", element.Alias)
	newTV.Update()
	set newTV = element.TaggedValues.AddNew("NVDB_navn", element.Name)
	newTV.Update()

	'GML-tagger for kodelister
	If element.Stereotype = "codeList" Then
		set newTV = element.TaggedValues.AddNew("asDictionary", "false")
		newTV.Update()
		set newTV = element.TaggedValues.AddNew("codeList", strTargetNamespace & element.Name)
		newTV.Update()
	End If
					
	element.TaggedValues.Refresh()
	element.Modified = Now
	element.Update
	
	
end sub