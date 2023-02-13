option explicit

!INC Local Scripts.EAConstants-VBScript
									   
!INC NVDB._felles
!INC NVDB._parametre
								 

' Script Name: DakatUML2SOSI_35_Attributter
' Author: Knut Jetlund
' Purpose: Oppdater SOSI-UML for attributter og kodelisteverdier fra oppdatert NVDB-UML
' Date: 2020-04-28

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
	eAttributt.Name = eAttrNVDB.Name
	eAttributt.Notes = eAttrNVDB.Notes
	eAttributt.LowerBound = 0
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
				if ucase(element.stereotype) = "FEATURETYPE" then
					Repository.WriteOutput "SOSI", Now & " Egenskapen " & element.Name & "." & eAttributt.Name & " (" & eAttributt.Alias & ") oppdateres til " & aTag.Value,0
					'Endrer navn på klassen til SOSI-modellnavn
					eAttributt.Name = aTag.Value
					'Lager ny tagged value på SOSI-elementet for SOSI-formatnavn (NVDB_ & Uppercase(element.Name))
					'Unntak: De som allerede har prefix "NVDB_" skal kun ha uppercase, ikke ny prefix
					set newATag = eAttributt.TaggedValues.AddNew("SOSI_navn", "")
					If Not Mid(eAttributt.Name, 1, 5) = "NVDB_" Then
						newATag.Value = "NVDB_" & Ucase(aTag.Value)
					Else
						newATag.Value = Ucase(aTag.Value)
					End If
					newATag.Update() 
				else
					'Kodelister: NVDB-navn som kodelisteverdi, sosi-navnet som intialverdi dersom den ikke er angitt fra kortverdi
					
					if eAttributt.Default = "" then 
						Repository.WriteOutput "SOSI", Now & " Kodelisteverdien " & element.Name & "." & eAttributt.Name & " (" & eAttributt.Alias & ") gis initialverdi " & aTag.Value,0
						eAttributt.Default = aTag.Value				
					end if	
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
			Case "Viktighet"
				'Settes som påkrevd kun dersom påkrevd i database
				If aTag.Value = "Påkrevd i database" then
					eAttributt.LowerBound = 1
				else
					eAttributt.LowerBound = 0
				end if	
				set newATag = eAttributt.TaggedValues.AddNew(aTag.Name, aTag.Value)
				newATag.Update()			
			Case else
				'Kopier tagged value uendra
				set newATag = eAttributt.TaggedValues.AddNew(aTag.Name, aTag.Value)
				newATag.Update()			

		end select
	next
	eAttributt.TaggedValues.Refresh
	
	'Datatype: Blank for kodelisteverdier
	If UCase(element.stereotype) = "CODELIST" then
		eAttributt.ClassifierID = 0
		eAttributt.Type = ""
		eAttributt.LowerBound = 1
		eAttributt.UpperBound = 1

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
					
					if not guidDT = "0" then
						aTag.Update 'aTag is usually updated outside this if, but i don't know if it needs to
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



function updateAttributes()
	'Oppdatering av attributter (egenskapstyper og kodelisteverdier)  
	'Setter opp kobling til modeller og databasetabell
	dim connect 
	connect = connect2UMLmodels()
	If not connect then exit function			  
  
	Repository.WriteOutput "Script", Now & " Oppdatering av vegobjekttyper i SOSI-modellregister", 0 
	Repository.WriteOutput "Script", Now & " ", 0 
	
    'Lag hjelpeliste: Datakatalogpakker med NVDB-ID og GUID
	Set lstNVDBpck = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Lager hjelpeliste over alle vegobjekttyper i NVDB Datakatalogen", 0 
	For each pkOT in pkObjekttyper.Packages
		Repository.WriteOutput "Script", Now & " NVDB-pakke: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
		lstNVDBpck.Add pkOT.Alias,pkOT.packageGUID
	Next

	dim keyIndex
	dim guid

	'Spoler gjennom alle NVDB Datakatalog-delpakker i SOSI-modellregister og sjekker egenskapstyper og kodelisteverdier
	Set lstSOSIpck = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Spoler gjennom alle NVDB Datakatalog-delpakker i SOSI-modellregister og sjekker klassene sine attributter/kodeverdier", 0 
	For each pkOT in pkSOSINVDB.Packages
		'Finner tilsvarende pakke i NVDB
		if lstNVDBpck.Contains(pkOT.Alias) then 
			'Henter NVDB-pakke vha listeinformasjon
			keyIndex = lstNVDBpck.IndexofKey(pkOT.Alias)
			guid = lstNVDBpck.GetByIndex(keyIndex)
			set pkOT_NVDB = Repository.GetPackageByGuid(guid)
			Repository.WriteOutput "Script", Now & " SOSI-pakke: " & pkOT.Name &  " (" & pkOT.Alias & ")", 0 
			'Repository.WriteOutput "Script", Now & " NVDB-pakke: " & pkOT_NVDB.Name &  " (" & pkOT_NVDB.Alias & ")", 0 
		else
			exit function
		end if
		
		'Løkke for alle klasser i SOSI-Modellen
		For idxE = 0 to pkOT.Elements.count -1 
			set element = pkOT.Elements.GetAt(idxE)
			'Søk etter NVDB-objekttypen
			set elNVDB = getElementByAlias(pkOT_NVDB, element.Alias)
			if not elNVDB is nothing then
				'Oppdaterer attributter under klassen
				Repository.WriteOutput "Script", Now & " Oppdaterer attributter/kodeverdier for: " & element.stereotype & " " & pkOT.Name & "." & element.Name &  " (" & element.Alias & ")", 0 

				lrAttr = false
				'Løkke for attributter i SOSI-modellen, sjekker om de finnes i NVDB Datakatalogen
				For idxA = 0 to element.Attributes.Count - 1
					Set eAttributt = element.Attributes.GetAt(idxA)
					if eAttributt.Name = "lineærPosisjon" then lrAttr = true
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
						if UCase(element.stereotype)="CODELIST" then 
							element.Attributes.DeleteAt idxA, False
							Repository.WriteOutput "Script", Now & " SOSI-Kodelisteverdi har ikke alias, slettes: " & element.Name &  "." & eAttributt.Name & " (" & eAttributt.Alias & ")", 0 
						end if	
						'NB! Egen håndtering av SOSI-attributter uten alias lenger ned (lineærPosisjon mm)
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

				'-----------------------------------------------------------------------------------------------------------------------------------
				'Generelle attributter: Stedfesting, retning, kjørefelt
				'Defaultverdier generelle attributter
				strStedfesting = "punkt"
				retning = False
				kjorefelt = 0
				
				'Kjører gjennom alle tagged values på NVDB-klassen og lagrer informasjon om generelle attributter
				For idxT = 0 To elNVDB.TaggedValues.Count - 1
					set tagVal = elNVDB.TaggedValues.GetAt(idxT)
					Select Case tagVal.Name
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
					End Select
				Next	
							
				if UCase(element.stereotype) = "FEATURETYPE" then
					'Stedfestingsegenskaper (geometri og lr)
					Select Case strStedfesting
						Case "strekning"
							If Not geomKurve Then
								'Legger til manglende egenskap for kurvegeometri
								Repository.WriteOutput "SOSI", Now & " Legger til geometriegenskap senterlinje på " & element.Name, 0
								set eAttributt = element.Attributes.AddNew("senterlinje", "")
								eAttributt.Pos = 99998
								eAttributt.Type = "Kurve"
								eAttributt.LowerBound = 0
								eAttributt.UpperBound = 1
								eAttributt.Notes = "Angivelse av objektets posisjon"							
								eAttributt.Visibility = "Public"							
								set aTag = eAttributt.TaggedValues.AddNew("SOSI_navn", "SENTERLINJE")
								aTag.Update()
								set elementB = Nothing
								'Finner kobling til riktig datatype
								set elementB = Repository.GetElementByGuid(guidKurve)
								If not elementB is Nothing then
									eAttributt.ClassifierID = elementB.ElementID
								end if 	
								eAttributt.Update()
							End If

							If not lrAttr Then
								'Legger til lr-posisjon for strekning
								Repository.WriteOutput "SOSI", Now & " Legger til egenskap lineærPosisjon (strekning) på " & element.Name, 0
								set eAttributt = element.Attributes.AddNew("lineærPosisjon", "")
								eAttributt.Pos = 99999
								eAttributt.Type = "LineærPosisjonStrekning"
								eAttributt.LowerBound = 0
								eAttributt.UpperBound = "*"
								eAttributt.Notes = "Angivelse av posisjon på det lineære objektet."
								eAttributt.Visibility = "Public"
								set constraint = element.Constraints.AddNew("Må ha minst en av stedfestingene lineærPosisjon og senterlinje", "OCL")
								constraint.Notes = "inv:count(self.senterlinje)+count(self.lineærposisjon)>0"
								constraint.Weight = 100
								constraint.Update()
								set aTag = eAttributt.TaggedValues.AddNew("SOSI_navn", "LRSTREKNING")
								aTag.Update()
								set elementB = Nothing
								'Finner kobling til riktig datatype
								set elementB = Repository.GetElementByGuid(guidLRStrekning)
								If not elementB is Nothing then
									eAttributt.ClassifierID = elementB.ElementID
								End if	
								eAttributt.Update()
							End if	
								
						Case "punkt"
							If Not geomPunkt Then
								'Legger til manglende egenskap for punktgeometri
								Repository.WriteOutput "SOSI", Now & " Legger til geometriegenskap posisjon på " & element.Name, 0
								set eAttributt = element.Attributes.AddNew("posisjon", "")
								eAttributt.Pos = 99998
								eAttributt.Type = "Punkt"
								eAttributt.LowerBound = 0
								eAttributt.UpperBound = 1
								eAttributt.Notes = "Angivelse av objektets posisjon"							
								eAttributt.Visibility = "Public"							
								set aTag = eAttributt.TaggedValues.AddNew("SOSI_navn", "POSISJON")
								aTag.Update()
								set elementB = Nothing
								'Finner kobling til riktig datatype
								set elementB = Repository.GetElementByGuid(guidKurve)
								if not elementB is Nothing then
									eAttributt.ClassifierID = elementB.ElementID
								End if	
								eAttributt.Update()
							End If

							If not lrAttr Then
								'Legger til lr-posisjon for punkt
								Repository.WriteOutput "SOSI", Now & " Legger til egenskap lineærPosisjon (punkt) på " & element.Name, 0
								set eAttributt = element.Attributes.AddNew("lineærPosisjon", "")
								eAttributt.Pos = 99999
								eAttributt.Type = "LineærPosisjonPunkt"
								eAttributt.LowerBound = 0
								eAttributt.UpperBound = "*"
								eAttributt.Notes = "Angivelse av posisjon på det lineære objektet."
								eAttributt.Visibility = "Public"
								set constraint = element.Constraints.AddNew("Må ha minst en av stedfestingene lineærPosisjon og posisjon", "OCL")
								constraint.Notes = "inv:count(self.posisjon)+count(self.lineærPosisjon)>0"
								constraint.Weight = 100
								constraint.Update()
								set aTag = eAttributt.TaggedValues.AddNew("SOSI_navn", "LRPUNKT")
								aTag.Update()
								set elementB = Nothing
								'Finner kobling til riktig datatype								
								set elementB = Repository.GetElementByGuid(guidLRPunkt)
								if not elementB is Nothing then
									eAttributt.ClassifierID = elementB.ElementID
								End If
								eAttributt.Update()
							End if
					End Select
					
					'Retning
					'Kjørefelt
					'Svingerestriksjoner...
				end if
			end if	
		Next 
		pkOT.Elements.Refresh		
	Next

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"
end function

