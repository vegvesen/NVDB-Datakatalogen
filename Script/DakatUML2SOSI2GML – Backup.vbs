option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

' Script Name: Generer applikasjonsskjema pr vegobjekttype
' Author: Knut Jetlund
' Purpose: Massiv generering av applikasjonsskjema pr vegobjekttype
' Date: 20160916
'
' NOTE: Requires a package to be selected in the Project Browser
' 

sub main()

	dim msgAnsw
	' Show and clear the script output window
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"

	' Get the currently selected package in the tree to work on
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
		
	if not thePackage is nothing and thePackage.ParentID <> 0 then
		
		Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 
		Repository.WriteOutput "Script", Now & " Kobler til ShapeChange-prosjektet " & scPath & "\" & scProject, 0 
		'Kobler til ShapeChange-prosjektet
		dim scRep as EA.Repository
		set scRep = CreateObject("EA.Repository")
		scRep.OpenFile(scPath & "\" & scProject)
		'Sletter alle eksisterende modeller i ShapeChange-prosjektet
		Repository.WriteOutput "Script", Now & " Sletter alle eksisterende modeller i ShapeChange-prosjektet", 0 
		dim scMod as EA.Package
		dim i
		for i = 0 to scRep.Models.Count -1
			set scMod = scRep.Models.GetAt(i)
			Repository.WriteOutput "Script", Now & " Sletter modellen " & scMod.Name, 0 
			scRep.Models.DeleteAt i,false
		next
		scRep.Models.Refresh		
		'Lager basismodell
		Repository.WriteOutput "Script", Now & " Lager modellen ShapeChange", 0 
		set scMod = scRep.Models.AddNew("ShapeChange","")
		scMod.Update	

		dim pck as EA.Package
		dim pI as EA.Project					
		set pI = scRep.GetProjectInterface()

		for each pck in thePackage.Packages
			if pck.Alias <> 532 then 'Vegreferanse skal ikke være med
				Repository.WriteOutput "Script", Now & " ", 0 
				Repository.WriteOutput "Script", Now & " Lager applikasjonsskjemamodell for delpakken " & pck.Name & " (" & pck.PackageGUID & ")", 0 

				'Sletter eksisterende pakker i modellen ShapeChange - oppretter hele modellen på nytt for hver vegobjekttype
				for i = 0 to scMod.Packages.Count-1
					scMod.Packages.DeleteAt i,false
				next
				scMod.Packages.Refresh
				
				'Lager hovedpakke i modellen ShapeChange
				Repository.WriteOutput "Script", Now & " Lager hovedpakke NVDB med pakketilpassede tagger", 0 
				dim scPck as EA.Package
				set scPck = scMod.Packages.AddNew("NVDB","")
				scPck.Update
				scMod.Packages.Refresh
				scPck.StereotypeEx="applicationSchema"
				scPck.Update

				'Setter GML-tagger på hovedpakka
				dim j
				dim el as EA.Element
				'dim nvn 
				'nvn = "nvdb"
				'Finner selve objekttypen og endrer norske tegn i navnet, for bruk i xsd-fil		
				for j = 0 to pck.Elements.Count -1
					set el = pck.Elements.GetAt(j)
					if el.Stereotype="featureType" then
				'		nvn = el.Name
				'		nvn= Replace(nvn, "æ","ae")
				'		nvn= Replace(nvn, "Æ","Ae")
				'		nvn= Replace(nvn, "ø","oe")
				'		nvn= Replace(nvn, "Ø","Oe")
				'		nvn= Replace(nvn, "å","aa")
				'		nvn= Replace(nvn, "Å","Aa")
						Repository.WriteOutput "Script", Now & " Vegobjekttype " & el.Name, 0 
						'Går ut av løkka, ettersom objekttypen er funnet. 
						j = pck.Elements.Count -1
					end if
				next
				
				'Legger på GML-tagger på hovedpakka. Litt komplekst pga tagger både i og utenfor profil
				dim lstTags
				Set lstTags = CreateObject("System.Collections.SortedList")
				lstTags.Add "targetNamespace", strTargetNamespace
				lstTags.Add "version", FC_version
				lstTags.Add "xmlns", "nvdb"
				lstTags.Add "xsdDocument", pck.Alias & ".xsd"
				
				dim tagVal as EA.TaggedValue
				dim tagFound
				
				for idxT = 0 to lstTags.Count - 1
					dim tName
					tName = lstTags.GetKey(idxT)
					dim tValue
					tValue = lstTags.GetByIndex(idxT)

					tagFound = false
					for each tagVal in scPck.Element.TaggedValues
						if tagVal.Name = tName then 
							tagVal.Value = tValue
							tagVal.Update
							tagFound= true
							Repository.WriteOutput "Script", Now & " Fant tagged value " & tagVal.Name & " = " & tagVal.Value, 0 
						end if
					next
					if not tagFound then 
						Repository.WriteOutput "Script", Now & " Mangler tag " & tName, 0 
						set tagVal = scPck.Element.TaggedValues.AddNew(tName, tValue)
						tagVal.Update
					end if
				next
				scPck.Element.TaggedValues.Refresh
				for each tagVal in scPck.Element.TaggedValues
					Repository.WriteOutput "Script", Now & " Tagged value " & tagVal.Name & " = " & tagVal.Value, 0 
				next

				scPck.Element.TaggedValues.Refresh
				scMod.Packages.Refresh	
				
				
				'Importerer SOSI Fellesegenskaper-pakken til modellen ShapeChange
				Repository.WriteOutput "Script", Now & " Importerer SOSI Fellesegenskaper-pakken", 0 
				pI.ImportPackageXMI scPck.PackageGUID, sosiPath & "\SOSI Fellesegenskaper.xml", 1,0
						
				'Finn SOSI Fellesegenskaper og sett GML-tagger
				dim pkSOSIfelles as EA.Package
				set pkSOSIfelles = scPck.Packages.GetByName("SOSI Fellesegenskaper")
				if not pkSOSIfelles is nothing then
					Repository.WriteOutput "Script", Now & " Pakken SOSI Fellesegenskaper er funnet i prosjektet (" & pkSOSIfelles.PackageGUID & ")", 0 
					'Setter GML-tagger på SOSI Fellesegenskaper
					set tagVal = pkSOSIfelles.Element.TaggedValues.AddNew("version", FC_version)
					tagVal.Update
					set tagVal = pkSOSIfelles.Element.TaggedValues.AddNew("xmlns", "nvdb")
					tagVal.Update
					set tagVal = pkSOSIfelles.Element.TaggedValues.AddNew("xsdDocument", "SOSIFelles.xsd")
					tagVal.Update				
					set tagVal = pkSOSIfelles.Element.TaggedValues.AddNew("xsdEncodingRule", "sosi")
					tagVal.Update
					scMod.Packages.Refresh		
				else
					Repository.WriteOutput "Script", Now & " Finner ikke pakken SOSI Fellesegenskaper", 0 
					scRep.Exit
					exit sub
				end if	

				'Importerer aktuell objekttype sin pakke til modellen ShapeChange
				Repository.WriteOutput "Script", Now & " Importerer pakke for hovedobjekttypen " & pck.Name & " (fil: " & sosiPath & "\" & pck.Alias & ".xml)", 0 
				pI.ImportPackageXMI scPck.PackageGUID, sosiPath & "\" & pck.Alias & ".xml", 1,0

				'Importer pakker for assosierte objekttyper
				dim con as EA.Connector
				dim assEl as EA.Element
				for each con in el.Connectors
					if con.SupplierID <> el.ElementID then
						set assEl = Repository.GetElementByID(con.SupplierID)
					else
						set assEl = Repository.GetElementByID(con.ClientID)
					end if
					'Importer assosiert pakke - ikke Vegreferanse
					if assEl.Alias <> 532 then
						Repository.WriteOutput "Script", Now & " Importerer pakke for vegobjekttype " & assEl.Name & " (fil: " & sosiPath & "\" & assEl.Alias & ".xml)", 0 
						pI.ImportPackageXMI scPck.PackageGUID, sosiPath & "\" & assEl.Alias & ".xml", 1,0
					end if	
				next
				'scMod.Update
				scPck.Packages.Refresh

				'Legger til arv fra SOSI Fellesegenskaper for alle objekttyper og rydder i tagger
				dim ftSOSIfelles as EA.Element
				set ftSOSIfelles = pkSOSIfelles.Elements.GetByName("Fellesegenskaper")

				if not ftSOSIfelles is nothing then
					Repository.WriteOutput "Script", Now & " Elementet Fellesegenskaper funnet (" & ftSOSIfelles.ElementGUID & ")", 0 
					dim scSubPck as EA.Package
					for each scSubPck in scPck.Packages
						'Fjerner eventuelle targetNamespace-tagger på delpakker
						for idxT = 0 to scSubPck.Element.TaggedValues.Count -1
							set tagVal = scSubPck.Element.TaggedValues.GetAt(idxT)
							if tagVal.Name = "targetNamespace" or tagVal.Value = "" then 
								Repository.WriteOutput "Script", Now & " Sletter tagged value " & scSubPck.Name & "." & tagVal.Name & " = " & tagVal.Value, 0 
								scSubPck.Element.TaggedValues.DeleteAt idxT,false
							end if
							if scSubPck.Alias = pck.Alias then
								'Fjerner alle tagged values på objekttypen sin pakke, den skal inngå i hovedpakken direkte.
								Repository.WriteOutput "Script", Now & " Sletter tagged value " & scSubPck.Name & "." & tagVal.Name & " = " & tagVal.Value, 0 
								scSubPck.Element.TaggedValues.DeleteAt idxT,false				
							end if
						next
						 scSubPck.Element.TaggedValues.Refresh
											
						if scSubPck.PackageGUID <> pkSOSIfelles.PackageGUID then
							dim scEl as EA.Element
							for each scEl In scSubPck.elements
								if scEl.Stereotype="featureType" then
									'Sletter alle constraints
									for idxC = 0 to scEl.Constraints.Count - 1
										scEl.Constraints.DeleteAt idxC, false
									next
									scEl.Constraints.Refresh
									'rydder opp i role tags
									Dim rTag As EA.RoleTag
									dim rTagFound
									for each con in scEl.Connectors
										rTagFound = false
										for idxT = 0 to con.ClientEnd.TaggedValues.Count - 1
											set rTag = con.ClientEnd.TaggedValues.GetAt(idxT)
											if rTag.Tag = "inlineOrByReference" and not rTagFound then
												rTag.Value = "ByReference"
												rTag.Update
												rTagFound = true
											elseif rTagFound then
												con.ClientEnd.TaggedValues.DeleteAt idxT, false
											end  if
										next
										con.ClientEnd.TaggedValues.Refresh()
										con.ClientEnd.Update()

										rTagFound = false
										for idxT = 0 to con.SupplierEnd.TaggedValues.Count - 1
											set rTag = con.SupplierEnd.TaggedValues.GetAt(idxT)
											if rTag.Tag = "inlineOrByReference" and not rTagFound then
												rTag.Value = "ByReference"
												rTag.Update
												rTagFound = true
											elseif rTagFound then
												con.SupplierEnd.TaggedValues.DeleteAt idxT, false
											end  if
										next
										con.SupplierEnd.TaggedValues.Refresh()
										con.SupplierEnd.Update()
									next
									
									If scEl.Name = "Dokumentasjon" Or scEl.Name = "Kommentar" Or scEl.Name = "Systemobjekt" Or Mid(scEl.Name, 1, 8) = "Tilstand" Then
										Repository.WriteOutput "Script", Now & " Legger ikke til arv fra SOSI Fellesegenskaper for objekttypen " & scEl.Name, 0
									Else
										Repository.WriteOutput "Script", Now & " Legger til arv fra SOSI Fellesegenskaper for objekttypen " & scEl.Name, 0
										set con = scEl.Connectors.AddNew("", "Generalization")
										con.ClientID = scEl.ElementID
										con.SupplierID = ftSOSIfelles.ElementID
										con.Update()
									End If
								end if
							next
						end if	
					next
				else
					Repository.WriteOutput "Script", Now & " Finner ikke elementet Fellesegenskaper", 0 
					scRep.Exit
					exit sub
				end if		

				'Kjører ShapeChange, venter på fullføring
				Repository.WriteOutput "Script", Now & " Kjører ShapeChange...", 0 
				dim strLine
				strLine = """C:\Program Files (x86)\AdoptOpenJDK\jre-14.0.1.7-hotspot\bin\java.exe"" -Xms256m -Xmx1024m -Dfile.encoding=UTF-8 -jar "
				strLine = strLine & """C:\DATA\Programvare\ShapeChange-2.9.1\ShapeChange-2.9.1.jar"" -c ""C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\SC\config\ShapeChangeConfiguration.xml"""
				dim shell
				set shell=createobject("wscript.shell") 
				shell.run strLine, 1, true
				set shell=nothing	
				
				
				'Flytter filer til riktig område
				Repository.WriteOutput "Script", Now & " Flytter filer til riktig område", 0 
				dim objFS
				Set objFS = CreateObject("Scripting.FileSystemObject")
				if not objFS.FolderExists(gmlPath & "\") then
					Repository.WriteOutput "Script", Now & " GML-mappen finnes ikke, oppretter", 0 
					objFS.CreateFolder gmlPath & "\"
				else
					'Repository.WriteOutput "Script", Now & " Mappen finnes ", 0 
				end if
				
				if objFS.FileExists(gmlPath & "\" & pck.Alias & ".xsd") then
					Repository.WriteOutput "Script", Now & " Skjemafilen " & pck.Alias & ".xsd finnes i GML-mappen fra før, slettes", 0 
					objFS.DeleteFile gmlPath & "\" & pck.Alias & ".xsd"
				else
					'Repository.WriteOutput "Script", Now & " Filen finnes ikke fra før", 0 
				end if
				If objFS.FileExists(scPath & "\XSD\INPUT\" & pck.Alias & ".xsd") then
					Repository.WriteOutput "Script", Now & " Flytter skjemafilen " & pck.Alias & ".xsd", 0 
					objFS.MoveFile scPath & "\XSD\INPUT\" & pck.Alias & ".xsd", gmlPath & "\"
				else
					Repository.WriteOutput "Error", Now & " Skjemafilen " & pck.Alias & ".xsd finnes ikke", 0 			
				end if
				
				'Hopp ut av løkka etter første pakke - fjernes når scriptet er ferdig.
				msgAnsw = MsgBox("Sjekk SC-modellen nå", vbOkCancel, "GML-applikasjonsskjema")
				if msgAnsw = 2 then
					scRep.Exit
					exit sub
				end if	

				'scRep.CloseFile
				'scRep.Exit
				'Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
				'exit sub
			end if
		next
		
		'Flytter SOSIFelles.xsd til riktig område
		Repository.WriteOutput "Script", Now & " Flytter skjemafil for fellesegenskaper til riktig område", 0 
		
		if objFS.FileExists(gmlPath & "\SOSIFelles.xsd") then
			Repository.WriteOutput "Script", Now & " Skjemafilen finnes i GML-mappen fra før slettes", 0 
			objFS.DeleteFile gmlPath & "\SOSIFelles.xsd"
		else
			'Repository.WriteOutput "Script", Now & " Filen finnes ikke fra før", 0 
		end if
		if objFS.FileExists(scPath & "\XSD\INPUT\SOSIFelles.xsd") then
			Repository.WriteOutput "Script", Now & " Flytter skjemafilen SOSIFelles.xsd", 0 
			objFS.MoveFile scPath & "\XSD\INPUT\SOSIFelles.xsd", gmlPath & "\"
		else
			Repository.WriteOutput "Error", Now & " Skjemafilen SOSIFelles.xsd finnes ikke", 0 
		end if

		Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
		Repository.EnsureOutputVisible "Script"
		scRep.CloseFile
		scRep.Exit
		set scRep = nothing	
	else
		' No package selected in the tree
		MsgBox( "This script requires a package to be selected in the Project Browser." & vbCrLf & _
			"Please select a package in the Project Browser and try again." )
	end if
	

end sub

main
