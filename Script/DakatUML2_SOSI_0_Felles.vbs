
!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

' Script Name: DakatUML2SOSI_1_Objekttyper
' Author: Knut Jetlund
' Purpose: Oppdater SOSI-UML for objekttyper og pakker ut fra oppdatert NVDB-UML
' Date: 2019-02-09

sub createPackage()
'Lager ny pakke som kopi av NVDB-pakke 
	set pkOT = pkSOSINVDB.Packages.AddNew(pkOT_NVDB.Name,"Package")
	pkOT.Update
	set element = pkOT.Element
	element.Alias = pkOT_NVDB.Alias
	element.Update
	updatePackage
end sub

sub updatePackage()
'Oppdaterer pakke med tilhørende klasser
	geomPunkt = False
	geomKurve = False
	
	'Oppdaterer properties på pakken
	pkOT.Name = pkOT_NVDB.Name
	pkOT.Notes = pkOT_NVDB.Notes
	pkOT.Version = FC_version
	pkOT.Update
	set element = pkOt.Element
	element.stereotype="applicationSchema"
	element.Update
	
	'Fjerner alle tagged values på pakken og legger til på nytt
	For idxT = 0 To element.TaggedValues.Count - 1
		element.TaggedValues.DeleteAt idxT, False
	Next
	'SOSI-tagger
	set tagVal = element.TaggedValues.AddNew("SOSI_kortnavn", "NVDB" & pkOT.Alias)
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("SOSI_langnavn", "NVDB " & pkOT.Name)
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("SOSI_organsasjon", "Statens vegvesen")
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("SOSI_produktgruppe", "NVDB")
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("SOSI_produsent", "Statens vegvesen")
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("SOSI_spesifikasjonstype", "Applikasjonsskjema")
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("SOSI_versjon", strSOSIVersjon)
	tagVal.Update()
	'GML-tagger 
	set tagVal = element.TaggedValues.AddNew("targetNamespace", strTargetNamespace)
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("version", pkOT.Version)
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("xmlns", "nvdb")
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("xsdDocument", pkOT.Alias & ".xsd")
	tagVal.Update()
	set tagVal = element.TaggedValues.AddNew("xsdEncodingRule", "sosi")
	tagVal.Update()

	updateClasses

end sub

sub updateClasses()
'Oppdaterer klasser (objekttyper og kodelister)

	'Løkke for alle klasser i SOSI-Modellen, sjekk for om de finnes i NVDB Datakatalogen
	For idxE = 0 to pkOT.Elements.count -1 
		set element = pkOT.Elements.GetAt(idxE)
		'Søk etter NVDB-objekttypen
		set elNVDB = getElementByAlias(pkOT_NVDB, element.Alias)
		if elNVDB is nothing then
			Repository.WriteOutput "Endringer", Now & " SOSI-Klassen finnes ikke i NVDB, fjernes: " & element.stereotype & " " & element.Name &  " (" & element.Alias & ")", 0 
			pkOT.Elements.DeleteAt idxE, False
		else
			'Oppdaterer properties på feature typen
			updateClassProperties
		end if	
	Next 
	pkOT.Elements.Refresh
	
	'Løkke for alle klasser i NVDB Datakatalogen, sjekk for om de finnes i SOSI-Modellen
	For each elNVDB in pkOT_NVDB.Elements
		set element = getElementByAlias(pkOT, elNVDB.Alias)
		if element is nothing then
			'Eksisterer ikke i SOSI, legges til
			Repository.WriteOutput "Endringer", Now & " NVDB-klassen finnes ikke i SOSI-modellregister, legges til: " & elNVDB.Name &  " (" & elNVDB.Alias & ")", 0 
			createClass
		else
			'Eksisterer i SOSI
			Repository.WriteOutput "Script", Now & " NVDB-klasse funnet i SOSI-modellregister: " & elNVDB.Name &  " (" & elNVDB.Alias & ")", 0 
		end if
	Next	
	
end sub

sub createClass()
'Lager ny klasse som kopi av NVDB-klasse 
	set element = pkOT.Elements.AddNew(elNVDB.Name,"Class")
	element.Alias = elNVDB.Alias
	element.Update
	pkOT.Elements.Refresh
	updateClassProperties
end sub

sub updateClassProperties()
'Oppdaterer properties for klasser (objekttyper og kodelister)
	if elNVDB.stereotype = "Vegobjekttype" then 
		element.stereotype = "featureType"
	ElseIf elNVDB.stereotype = "Tillatte verdier" then 
		element.stereotype = "CodeList" 
	End if 
	element.Notes = elNVDB.Notes
	element.Version = FC_version
	element.TreePos = elNVDB.TreePos
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
	'Kører gjennom alle tagged values på NVDB-pakken og overører informasjon
	For idxT = 0 To elNVDB.TaggedValues.Count - 1
		set tagVal = elNVDB.TaggedValues.GetAt(idxT)
		Select Case tagVal.Name
			Case "SOSI_navn"
				'SOSI-navn på objekttypen. Brukes for å sette SOSI-modellnavn og SOSI-formatnavn
				Repository.WriteOutput "SOSI", Now & " Klassen " & element.Name & " (" & element.Alias & ") oppdateres til " & element.Stereotype & " " & tagVal.Value,0
				'Endrer navn på klassen til SOSI-modellnavn
				element.Name = tagVal.Value
				'Lager ny tagged value pÃ¥ SOSI-elementet for SOSI-formatnavn (NVDB_ & Uppercase(element.Name))
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
				' ****** Her gjenstår det noe, må løses for kodelister ******
			Case "TOTAL_FELTLENGDE"
				'Feltlengde - tas vare på for SOSI-realisering (kun kodelister)
				set newTV = element.TaggedValues.AddNew("SOSI_lengde", tagVal.Value)
				newTV.Update()
			Case "NAVN_VOBJ_TYPE", "NAVN_EGENSKAPSTYPE"
				'NVDB-navn
				set newTV = element.TaggedValues.AddNew("NVDB_navn", tagVal.Value)
				newTV.Update()
			Case "ID_VOBJ_TYPE", "ID_EGENSKAPSTYPE"
				'ID - gi nytt navn til tagged value
				tagVal.Name = "NVDB_ID"
				tagVal.Update()
		End Select
	Next	

	'Lager tagged values direkte fra navn og alias
	set newTV = element.TaggedValues.AddNew("catalogue-entry", "NVDB Datakatalogen")
	newTV.Update()
	set newTV = element.TaggedValues.AddNew("NVDB_ID", element.Alias)
	newTV.Update()

	'GML-tagger for kodelister
	If element.Stereotype = "codeList" Then
		set newTV = element.TaggedValues.AddNew("asDictionary", "false")
		newTV.Update()
		set newTV = element.TaggedValues.AddNew("codeList", strTargetNamespace & element.Name)
		newTV.Update()
		
		'SOSI_Datatype for kodelisten
		'Søk etter NVDB-objekttypen, attributt tilhørende kodelisten og dennes datatype
		dim elVOT as EA.Element
		set elVOT = getElementByAlias(pkOT_NVDB, pkOT_NVDB.Alias)
		If not elVOT is Nothing then
			Dim aVET as EA.Attribute
			set aVET = getAttributeByAlias(elVOT, element.Alias)
			if not aVET is Nothing then
				'Finn datatype-element
				Set elementDT = Nothing
				Set elementDT = Repository.GetElementByID(aVET.ClassifierID)
				If not elementDT is Nothing then
					'Sett SOSI-tag for SOSI_datatype
					Select Case elementDT.Alias
						Case 30
							set newTV = element.TaggedValues.AddNew("SOSI_datatype", "T")
						Case 31
							If aVET.Precision = 0 Then
								set newTV = element.TaggedValues.AddNew("SOSI_datatype", "H")
							Else
								set newTV = element.TaggedValues.AddNew("SOSI_datatype", "D")
							End If
					End Select
					newTV.Update
					Repository.WriteOutput "SOSI", Now & " Kodeliste: " & element.stereotype & " " & element.Name &  " SOSI_datatype " & newTV.Value, 0 
				end if
			end if
		end if
	End If
					
	element.TaggedValues.Refresh()
	element.Modified = Now
	element.Update
	
	'Løkke for attributter i SOSI-modellen, sjekker om de finnes i NVDB Datakatalogen
	For idxA = 0 to element.Attributes.Count - 1
		Set eAttributt = element.Attributes.GetAt(idxA)
		'Repository.WriteOutput "Script", Now & " Egenskapstype: " & element.Name &  "." & eAttributt.Name, 0 
		if not eAttributt.Alias = "" then
			set eAttrNVDB = getAttributeByAlias(elNVDB, eAttributt.Alias)
			If eAttrNVDB is nothing then 
				Repository.WriteOutput "Endringer", Now & " SOSI-Egenskapstype/kodelisteverdi finnes ikke i NVDB, fjernes: " & pkOT.name & "." & element.Name &  "." & eAttributt.Name & " (" & eAttributt.Alias & ")", 0 
				element.Attributes.DeleteAt idxA, False
			else
				Repository.WriteOutput "Script", Now & " SOSI-Egenskapstype/kodelisteverdi finnes i NVDB, oppdateres: " & element.Name &  "." & eAttributt.Name & " (" & eAttributt.Alias & ")", 0 
				updateAttributeProperties
			end if 
		else
			'egen håndtering av SOSI-attributter uten alias (lineærPosisjon mm)
		end if	
	Next
	element.Attributes.Refresh
	
	'Løkke for alle attributter i NVDB Datakatalogen, sjekk for om de finnes i SOSI-Modellen
	For each eAttrNVDB in elNVDB.Attributes
		set eAttributt = getAttributeByAlias(element, eAttrNVDB.Alias)
		if eAttributt is nothing then
			'Eksisterer ikke i SOSI, legges til
			Repository.WriteOutput "Endringer", Now & " NVDB-egenskapstype/kodelisteverdi finnes ikke i SOSI-modellregister, legges til: " & pkOT.name & "." & element.name & "." & eAttrNVDB.Name &  " (" & eAttrNVDB.Alias & ")", 0 
			createAttribute
		else
			'Eksisterer i SOSI
			Repository.WriteOutput "Script", Now & " NVDB-egenskapstype/kodelisteverdi funnet i SOSI-modellregister: " & eAttrNVDB.Name &  " (" & eAttrNVDB.Alias & ")", 0 
		end if
	Next
	
	if UCase(element.stereotype) = "FEATURETYPE" then
		'Stedfestingsegenskaper (geometri og lr)
		
		
		
		'Retning
		'Kjørefelt
		'Svingerestriksjoner...
	end if
	
	
end sub

sub createAttribute()
'Lager ny attributt/egenskapstype
	set eAttributt = element.Attributes.AddNew(eAttrNVDB.Name, "")
	eAttributt.Alias = eAttrNVDB.Alias
	eAttributt.Update
	element.Attributes.Refresh
	updateAttributeProperties
end sub

sub updateAttributeProperties()
'Oppdaterer properties på egenskapstyper

	eAttributt.Notes = eAttrNVDB.Notes
	eAttributt.LowerBound = eAttrNVDB.LowerBound
	eAttributt.UpperBound = eAttrNVDB.UpperBound
	eAttributt.Precision = eAttrNVDB.Precision
	eAttributt.Pos = eAttrNVDB.Pos
	if UCase(element.stereotype) = "CODELIST" and eAttrNVDB.Default <> "" then eAttributt.Default = eAttrNVDB.Default
	eAttributt.Update
	
	'Fjerner alle tagged values på attributten og legger til på nytt
	For idxT = 0 To eAttributt.TaggedValues.Count - 1
		eAttributt.TaggedValues.DeleteAt idxT, False
	Next	
	
	dim newATag as EA.AttributeTag
	for each aTag in eAttrNVDB.TaggedValues
		select case aTag.Name
			Case "SOSI_navn"
				'SOSI-navn på egenskapstypen. Brukes for å sette SOSI-modellnavn og SOSI-formatnavn
				Repository.WriteOutput "SOSI", Now & " Egenskapen/kodelisteverdien " & element.Name & "." & eAttributt.Name & " (" & eAttributt.Alias & ") oppdateres til " & aTag.Value,0
				'Endrer navn på klassen til SOSI-modellnavn
				eAttributt.Name = aTag.Value
				if ucase(element.stereotype) = "FEATURETYPE" then
					'Lager ny tagged value på SOSI-elementet for SOSI-formatnavn (NVDB_ & Uppercase(element.Name))
					'Unntak: De som allerede har prefix "NVDB_" skal kun ha uppercase, ikke ny prefix
					set newATag = eAttributt.TaggedValues.AddNew("SOSI_navn", "")
					If Not Mid(eAttributt.Name, 1, 5) = "NVDB_" Then
						newATag.Value = "NVDB_" & Ucase(aTag.Value)
					Else
						newATag.Value = Ucase(aTag.Value)
					End If
					newATag.Update() 
				end if	
			Case "NAVN_EGENSKAPSTYPE", "NAVN_TILLATT_VERDI"
				'NVDB-navn
				set newATag = eAttributt.TaggedValues.AddNew("NVDB_navn", aTag.Value)
				newATag.Update()
			Case "ID_EGENSKAPSTYPE", "ID_TILLATT_VERDI"
				'ID - gi nytt navn til tagged value
				set newATag = eAttributt.TaggedValues.AddNew("NVDB_ID", aTag.Value)
				newATag.Update()	
			Case "TOTAL_FELTLENGDE"
				'Feltlengde - tas vare på for SOSI-realisering
				set newATag = eAttributt.TaggedValues.AddNew("SOSI_lengde", aTag.Value)
				newATag.Update()
			'SOSI_datatype: Egen prosess
		end select
	next
	eAttributt.TaggedValues.Refresh
	
	'Datatype: Blank for kodelisteverdier
	If UCase(element.stereotype) = "CODELIST" then
		eAttributt.ClassifierID = 0
		eAttributt.Type = ""
	else
		'Sett datatype
		Set elementDT = Nothing
		Set elementDT = Repository.GetElementByID(eAttrNVDB.ClassifierID)
		If not elementDT is Nothing then
			if elementDT.Alias = 30 or elementDT.Alias = 31 then
				'Kodeliste
				'Bruk egenskapen sin alias til å finne selve kodelisten, og sett den som datatype
				set elementCL= getElementByAlias(pkOT, eAttributt.Alias)
				if not elementCL is Nothing then
					eAttributt.Type = elementCL.Name
					eAttributt.ClassifierID = elementCL.ElementID
					'Sett SOSI-tag for defaultcodespace 
					set aTag = eAttributt.TaggedValues.AddNew("defaultCodespace", strTargetNamespace & elementCL.Name & ".xml")
					'Sett SOSI-tag for SOSI_datatype
					Select Case elementDT.Alias
						Case 30
							set aTag = eAttributt.TaggedValues.AddNew("SOSI_datatype", "T")
						Case 31
							If eAttributt.Precision = 0 Then
								set aTag = eAttributt.TaggedValues.AddNew("SOSI_datatype", "H")
							Else
								set aTag = eAttributt.TaggedValues.AddNew("SOSI_datatype", "D")
							End If
					End Select
					aTag.Update
					eAttributt.TaggedValues.Refresh
					eAttributt.Update
					Repository.WriteOutput "SOSI", Now & " Datatype og SOSI-tag for " & element.stereotype & " " & element.Name &  "." & eAttributt.Name & ": " & eAttributt.Type & " SOSI_datatype " & aTag.Value, 0 
				end if
			else
				'Simpel datatype, mappes til SOSI-datatyper
				set tagVal = Nothing
				set tagVal = elementDT.TaggedValues.GetByName("SOSI_type")
				if not tagVal is nothing then
					eAttributt.Type = tagVal.Value
					'Finner ID for aktuell SOSI-datatype. Tilpasser navn på geometriegenskaper, og registrerer om objekttypen har påkrevde geometriegenskaper
					Dim guidDT 
					guidDT  = "0"
					Select Case eAttributt.Type
						Case "CharacterString"
							guidDT = guidCharacterString
							set aTag = eAttributt.TaggedValues.AddNew("SOSI_datatype", "T")
						Case "Real"
							If eAttributt.Precision = "0" Then
								'Endrer til Integer
								guidDT = guidInteger
								eAttributt.Type = "Integer"
								set aTag = eAttributt.TaggedValues.AddNew("SOSI_datatype", "H")
							Else
								guidDT = guidReal
								set aTag = eAttributt.TaggedValues.AddNew("SOSI_datatype", "D")
							End If
						Case "Date"
							guidDT = guidDate
							set aTag = eAttributt.TaggedValues.AddNew("SOSI_datatype", "DATO")
						Case "Boolean"
							guidDT = guidBoolean
							set aTag = eAttributt.TaggedValues.AddNew("SOSI_datatype", "Boolsk")
						Case "Punkt"
							guidDT = guidPunkt
							eAttributt.Name = "posisjon"
							geomPunkt = True
							set aTag = eAttributt.TaggedValues.AddNew("SOSI_datatype", "PUNKT")
						Case "Kurve"
							guidDT = guidKurve
							eAttributt.Name = "senterlinje"
							geomKurve = True
							set aTag = eAttributt.TaggedValues.AddNew("SOSI_datatype", "KURVE")
						Case "Flate"
							guidDT = guidFlate
							eAttributt.Name = "område"
							set aTag = eAttributt.TaggedValues.AddNew("SOSI_datatype", "FLATE")
					End Select
					aTag.Update
					if not guidDT = "0" then
						set elementB = Repository.GetElementByGuid(guidDT)
						eAttributt.ClassifierID = elementB.ElementID
						Repository.WriteOutput "SOSI", Now & " Datatype og SOSI-tag for " & element.stereotype & " " & element.Name &  "." & eAttributt.Name & ": " & eAttributt.Type & " SOSI_datatype " & aTag.Value, 0 
					End If
				end if
			end if
		end if
	end if
	eAttributt.Update
	
end sub
