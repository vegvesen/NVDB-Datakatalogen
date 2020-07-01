option explicit

!INC Local Scripts.EAConstants-VBScript
									   
!INC NVDB._felles
!INC NVDB._parametre
								 

' Script Name: DakatUML2SOSI_X_AbstrakteKlasser
' Author: Knut Jetlund
' Purpose: Lager nivå med abstrakte klasser i SOSI-NVDB-modellen, for å lette implementering i GML
' Date: 2020-06-04

dim absCon as EA.Connector
dim absAssEl as EA.Element
dim assEl as EA.Element

sub abstractClasses()
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"

	set ePIF = Repository.GetProjectInterface

	'Hent hovedpakken for NVDB Datakatalogen i SOSI-modellregister
	set pkSOSINVDB = Repository.GetPackageByGuid(guidSOSIDatakatalog)
	dim absPck as EA.Package
	set absPck = Repository.GetPackageByGuid(guidAbstrakteKlasser)
	dim absElement as EA.Element
	

	dim keyIndex
	dim guid
	dim msgAnsw
	
	dim lstAbsCls
	Set lstAbsCls = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Lager hjelpeliste over alle eksisterende abstrakte klasser ", 0 
	For each absElement in absPck.Elements
		Repository.WriteOutput "Script", Now & " Abstrakt klasse: " & absElement.Name &  " (" & absElement.Alias & ")", 0 
		lstAbsCls.Add absElement.Alias, absElement.ElementGUID
	Next

	Repository.WriteOutput "Script", Now & " Hovedpakke: " & pkSOSINVDB.Name & " (" & pkSOSINVDB.PackageGUID & ")", 0 
	'Løkke for assosiasjonsdiagrammer. Erstatter alle konkrete klasser med abstrakte klasser
	Repository.WriteOutput "Script", Now & "  ", 0 
	for each pkOT in pkSOSINVDB.Packages
		if pkOT.PackageGUID <> guidAbstrakteKlasser then 
			Repository.WriteOutput "Script", Now & " ------------------------------------------------------------------------------", 0 
			Repository.WriteOutput "Script", Now & " Oppdaterer assosiasjonsdiagram for pakken " & pkOT.Name, 0 
			for each eDiagram in pkOT.Diagrams
				if eDiagram.Name = pkOT.Name & " Assosiasjoner" then
					Repository.WriteOutput "Script", Now & " Diagram: " & eDiagram.Name, 0 
					dim concreteCls
					concreteCls = false
					for each diagramObject in eDiagram.DiagramObjects
						set element = Repository.GetElementByID(diagramObject.ElementID)
						if element.Alias <> pkot.Alias and lstAbsCls.Contains(element.Alias) then 
							keyIndex = lstAbsCls.IndexofKey(element.Alias)
							guid = lstAbsCls.GetByIndex(keyIndex)
							set absElement = Repository.GetElementByGuid(guid)
							if absElement.ElementID <> element.ElementID then 
								Repository.WriteOutput "Script", Now & " Erstatter konkret klasse med abstrakt klasse: " & absElement.Name, 0		
								diagramObject.ElementID = absElement.ElementID
								diagramObject.Update
							end if	
						end if
						if element.Alias = pkOT.Alias and element.Abstract = 0 then
							'Den konkrete hovedklassen finnes i diagrammet
							Repository.WriteOutput "Script", Now & " Konkret hovedklasse funnet i diagrammet: " & element.Name, 0		
							concreteCls = true
						else
							setSize diagramObject, 70, 200
						end if
					next
					if not concreteCls then
						'Den konkrete hovedklassen finnes ikke i diagrammet. Legger til. 
						Repository.WriteOutput "Script", Now & " Konkret hovedklasse mangler i diagrammet", 0		
						for each element in pkOT.Elements
							if UCase(element.Stereotype) = "FEATURETYPE" then
								Repository.WriteOutput "Script", Now & " Legger til konkret hovedklasse: " & element.Name, 0		
								set diagramObject = eDiagram.DiagramObjects.AddNew("", "")
								diagramObject.ElementId = element.ElementID
								diagramObject.Update
							end if
						next			
					end if
					ePIF.LayoutDiagramEx eDiagram.DiagramGUID, 4, 4, 20, 20, True
					repository.CloseDiagram(eDiagram.DiagramID)
				end if
			next
		end if	
		'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
		'msgAnsw = MsgBox("Sjekk modellen nå", vbOkCancel, "GML-applikasjonsskjema")
		'if msgAnsw = 2 then
		'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		'	exit sub
		'end if	
		
	next
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"
end sub

abstractClasses()