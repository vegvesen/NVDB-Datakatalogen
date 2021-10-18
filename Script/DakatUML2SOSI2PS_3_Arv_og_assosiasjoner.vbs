'option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

' Script Name: DakatUML2SOSI2PS_2_Arv_og_assosiasjoner
' Author: Knut Jetlund
' Purpose: Arv fra SOSI-Fellesegenskaper, og opprydding i assosiasjoner
' Date: 20210217
'

const votkatId = "303,304"

sub main

	'Vise og tøm scriptvinduer
	outputTabs
	'Kobler til modell og database
	connect2models

	'Hent valgt hovedpakke
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
	Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 
	
	dim pI as EA.Project					
	set pI = Repository.GetProjectInterface()
	Set objFS = CreateObject("Scripting.FileSystemObject")

	'Finner pakken med abstrakte klasser i hovedmodellen for NVDB i SOSI-modellregister
	dim absPck as EA.Package
	set absPck = Repository.GetPackageByGuid(guidAbstrakteKlasser)
	if not absPck is nothing then
		Repository.WriteOutput "Script", Now & " Pakken med abstrakte klasser er funnet i prosjektet (" & absPck.PackageGUID & ")", 0 
	else
		Repository.WriteOutput "Script", Now & " Finner ikke pakken _AbstrakteKlasser", 0 
		exit sub
	end if	

	dim katPackage as EA.Package
	for each katPackage in thePackage.Packages
		Repository.WriteOutput "Script", Now & " Pakke for kategori: " & katPackage.Name & " (" & katPackage.Alias & ")", 0 

		'TODO: Flytte assosiasjoner fra abstrakte klasser til de opprinnelige
		'Lager hjelpeliste over alle vegobjekttyper i modellen og deres alias (NVDB-ID)
		dim lstCls
		Set lstCls = CreateObject("System.Collections.SortedList")
		Repository.WriteOutput "Script", Now & " Lager hjelpeliste over alle vegobjekttyper i modellen og deres alias (NVDB-ID)", 0 
		for idxP = 0 to katPackage.Packages.Count - 1
			set pkOT = katPackage.Packages.GetAt(idxP)
			if pkOT.Name = "SOSI Fellesegenskaper" then
				katPackage.Packages.DeleteAt idxP, 0
			else	
				for each element in pkOT.Elements
					If UCase(element.Stereotype)="FEATURETYPE" then
						Repository.WriteOutput "Script", Now & " Vegobjekttype: " & element.Name & " (" & element.Alias & ")", 0 
						lstCls.Add element.Alias, element.ElementGUID
					end if	
				Next
			end if
		Next
		katPackage.Packages.Refresh
		
		'Importer pakken med SOSI Fellesegenskaper
		dim ftSOSIfelles as EA.Element
		Repository.WriteOutput "Script", Now & " Importerer pakken SOSI Fellesegenskaper", 0 
		pI.ImportPackageXMI katPackage.PackageGUID, sosiPath & "\SOSI Fellesegenskaper.xml", 1,1
		katPackage.Packages.Refresh
		set pkSOSIfelles = katPackage.Packages.GetByName("SOSI Fellesegenskaper")
		if not pkSOSIfelles is nothing then
			Repository.WriteOutput "Script", Now & " Pakken SOSI Fellesegenskaper er funnet i kategoripakken (" & pkSOSIfelles.PackageGUID & ")", 0 
			set ftSOSIfelles = pkSOSIfelles.Elements.GetByName("Fellesegenskaper")
			if not ftSOSIfelles is nothing then
				Repository.WriteOutput "Script", Now & " Elementet Fellesegenskaper funnet (" & ftSOSIfelles.ElementGUID & ")", 0 
			else	
				Repository.WriteOutput "Script", Now & " Finner ikke Elementet SOSI Fellesegenskaper. Avslutter", 0 
			exit sub
		end if 
		else
			Repository.WriteOutput "Script", Now & " Finner ikke pakken SOSI Fellesegenskaper. Avslutter", 0 
			exit sub
		end if 
		
		'Kjører gjennom alle vegobjekttypepakker og klasser, 
		'og flytter assosiasjoner fra abstrakte klasser til de originale klassene i kategoripakken
		'Legger også til arv fra SOSI Fellesegenskaper
		for each pkOT in katPackage.Packages
			if pkOT.PackageGUID <> pkSOSIfelles.PackageGUID then 
				Repository.WriteOutput "Script", Now & " Pakke: " & pkOT.Name & " (" & pkOT.Alias & ")", 0 
				for each element in pkOT.Elements
					If UCase(element.Stereotype)="FEATURETYPE" then
						'Featuretype
						Repository.WriteOutput "Script", Now & " Vegobjekttype: " & element.Name & " (" & element.Alias & ")", 0 
						For idxC = 0 to element.Connectors.Count - 1
							set con = element.Connectors.GetAt(idxC)
							if con.ClientID = element.ElementID then 
								set assEl = Repository.GetElementByID(con.SupplierID)
							else
								set assEl = Repository.GetElementByID(con.ClientID)
							end if
							'Sjekk om det er riktig type connector
							if (con.type = "Aggregation" or con.Type = "Association") then
								'Sjekk om assosiert element er client eller supplier
								if assEl.Abstract = 1 then
									'Assosiasjon til abstrakt klasse, skal endres
									Repository.WriteOutput "Script", Now & " Assosiasjon skal endres: " & assEl.Name & "(" & assEl.Alias & ")", 0 
									'Finn originalt element vha listeoppslag						
									if lstCls.Contains(assEl.Alias) then
										'Finn selve elementet
										keyIndex = lstCls.IndexofKey(assEl.Alias)
										guid = lstCls.GetByIndex(keyIndex)
										set elementB = Repository.GetElementByGuid(guid)
										Repository.WriteOutput "Script", Now & " Original klasse med alias " & assEl.Alias & " funnet, flytter assosiasjon", 0 
										'Flytt assosiasjon over til originalt element
										if con.ClientID = element.ElementID then 
											con.SupplierID = elementB.ElementID
										else
											con.ClientID = elementB.ElementID
										end if
										con.Update
									else
										'Assosiert klasse finnes ikke i denne modellen, assosasjon slettes
										Repository.WriteOutput "Script", Now & " Assosiasjon skal slettes: Original klasse med alias " & assEl.Alias & " er ikke i denne modellen", 0 
										element.Connectors.DeleteAt idxC, false
									end if
								end if	
							elseif con.Type = "Generalization" and assEl.Alias = element.Alias and assEl.Abstract = 1 then
								'Arv fra egen abstrakt klasse, fjernes
								Repository.WriteOutput "Script", Now & " Generalisering skal slettes: " & assEl.Alias, 0 
								element.Connectors.DeleteAt idxC, false
							end if				
						Next
						element.Connectors.Refresh
						
						'Legger til arv fra SOSIFelles til vegobjekttypen
						Repository.WriteOutput "Script", Now & " Legger til arv fra SOSI Fellesegenskaper for objekttypen " & element.Name, 0
						set con = element.Connectors.AddNew("", "Generalization")
						con.ClientID = element.ElementID
						con.SupplierID = ftSOSIfelles.ElementID
						con.Update()
					end if	
				next
					
				'Finner diagrammer i pakken
				set eBDiagram = Nothing
				set eTVDiagram = Nothing
				set eASDiagram = Nothing
				for each eDiagram in pkOT.Diagrams
					if eDiagram.Name = pkOT.Name & " Assosiasjoner" then set eASDiagram = eDiagram
					If eDiagram.Name = pkOT.Name & " Betingelser" then set eBDiagram = eDiagram
					If eDiagram.Name = pkOT.Name & " Tillatte verdier" then set eTVDiagram = eDiagram
				next
				'Repository.WriteOutput "Script", Now & " Assosiasjonsdiagram: " & eASDiagram.Name, 0 
				Repository.WriteOutput "Script", Now & " Rydder i betingelsessdiagrammet: " & eBDiagram.Name, 0 
				'Fjerner klassen og legger til på nytt for å få automatisk tilpasset størrelse
				for idxD = 0 to eBDiagram.DiagramObjects.Count - 1
					Set diagramObject = eBDiagram.DiagramObjects.GetAt(idxD)
					set element = Repository.GetElementByID(diagramObject.ElementID)
					eBDiagram.DiagramObjects.DeleteAt idxD, 0
					set diagramObject = eBDiagram.DiagramObjects.AddNew("", "")
					diagramObject.ElementID = element.ElementID
					diagramObject.Update()
				next
				eBDiagram.DiagramObjects.Refresh
				ePIF.LayoutDiagramEx eBDiagram.DiagramGUID, 4, 4, 20, 20, True
				repository.CloseDiagram(eBDiagram.DiagramID)

				Repository.WriteOutput "Script", Now & " Rydder i kodelistediagrammet: " & eTVDiagram.Name, 0 
				'Fjerner klasser og legger til på nytt for å få automatisk tilpasset størrelse
				for idxD = 0 to eTVDiagram.DiagramObjects.Count - 1
					Set diagramObject = eTVDiagram.DiagramObjects.GetAt(idxD)
					set element = Repository.GetElementByID(diagramObject.ElementID)
					eTVDiagram.DiagramObjects.DeleteAt idxD, 0
					set diagramObject = eTVDiagram.DiagramObjects.AddNew("", "")
					diagramObject.ElementID = element.ElementID
					diagramObject.Update()
				next
				eTVDiagram.DiagramObjects.Refresh
				ePIF.LayoutDiagramEx eTVDiagram.DiagramGUID, 4, 4, 20, 20, True
				repository.CloseDiagram(eTVDiagram.DiagramID)
	
				'Endrer og sletter klasser i assosiasjonsdiagrammet
				Repository.WriteOutput "Script", Now & " Rydder i assosiasjonsdiagrammet: " & eASDiagram.Name, 0 
				for idxD = 0 to eASDiagram.DiagramObjects.Count - 1
					Set diagramObject = eASDiagram.DiagramObjects.GetAt(idxD)
					set element = Repository.GetElementByID(diagramObject.ElementID)
					if element.Abstract = 1 then
						if element.Alias = pkOT.Alias or not lstCls.Contains(element.Alias) then
							'Slett vegobjektets egen abstrakte klasse og klasser som ikke skal være med
							Repository.WriteOutput "Script", Now & " Fjerner klassen " & element.Name & " fra assosiasjonsdiagramet", 0 
							eASDiagram.DiagramObjects.DeleteAt idxD, 0
						elseif lstCls.Contains(element.Alias) then
							'Endre fra abstrakt objekt til originalt objekt
							'Finn selve elementet
							keyIndex = lstCls.IndexofKey(element.Alias)
							guid = lstCls.GetByIndex(keyIndex)
							set elementB = Repository.GetElementByGuid(guid)
							Repository.WriteOutput "Script", Now & " Endrer klassen " & element.Name & " til " & elementB.Name & " i assosiasjonsdiagramet", 0 
							diagramObject.ElementID = elementB.ElementID
							diagramObject.Update
						end if
					elseif element.Alias = pkOT.Alias then
						'Hovedklassen - fjerner og legger til på nytt for å få automatisk tilpasset størrelse
						eASDiagram.DiagramObjects.DeleteAt idxD, 0
						set diagramObject = eASDiagram.DiagramObjects.AddNew("", "")
						diagramObject.ElementID = element.ElementID
						diagramObject.Update()
					end if	
				next
				eASDiagram.DiagramObjects.Refresh
				ePIF.LayoutDiagramEx eASDiagram.DiagramGUID, 4, 4, 20, 20, True
				repository.CloseDiagram(eASDiagram.DiagramID)

			end if	
		next

		'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
		'dim msgAnsw
		'msgAnsw = MsgBox("Sjekk modellen nå", vbOkCancel, "OWL")
		'if msgAnsw = 2 then
		'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		'	exit sub
		'end if	
	
	next

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		

end sub

main()