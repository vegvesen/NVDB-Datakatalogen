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
const ns = "https://raw.githubusercontent.com/jetgeo/NVDBGML/master/XSD/NVDB"

sub main()
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
		Repository.WriteOutput "Script", Now & " Kobler til ShapeChange-prosjektet", 0 
		'Kobler til ShapeChange-prosjektet
		dim scRep as EA.Repository
		set scRep = CreateObject("EA.Repository")
		scRep.OpenFile("C:\DATA\GitHub\NVDBGML\ShapeChange.eap")
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
		for each pck in thePackage.Packages
			Repository.WriteOutput "Script", Now & " ", 0 
			Repository.WriteOutput "Script", Now & " ", 0 
			If pck.Name = "Dokumentasjon" Or pck.Name = "Kommentar" Or pck.Name = "Systemobjekt" Or Mid(pck.Name, 1, 8) = "Tilstand" Then
				Repository.WriteOutput "Script", Now & " Lager ikke egen modell for delpakken " & pck.Name, 0
			else	
				Repository.WriteOutput "Script", Now & " Lager applikasjonsskjemamodell for delpakken " & pck.Name & " (" & pck.PackageGUID & ")", 0 
				'Sletter eksisterende pakker i modellen ShapeChange
				for i = 0 to scMod.Packages.Count-1
					scMod.Packages.DeleteAt i,false
				next
				scMod.Packages.Refresh
			
				dim j
				dim el as EA.Element
				'Finner selve objekttypen
				for j = 0 to pck.Elements.Count -1
					set el = pck.Elements.GetAt(j)
					if el.Stereotype="featureType" then
						'Her starter moroa!
						dim id
						id = pck.Alias
						dim nvn 
						nvn = el.Name
				
						nvn= Replace(nvn, "æ","ae")
						nvn= Replace(nvn, "Æ","Ae")
						nvn= Replace(nvn, "ø","oe")
						nvn= Replace(nvn, "Ø","Oe")
						nvn= Replace(nvn, "å","aa")
						nvn= Replace(nvn, "Å","Aa")
						'Lager hovedpakke
						Repository.WriteOutput "Script", Now & " Lager hovedpakke NVDB for " & nvn, 0 
						dim scPck as EA.Package
						set scPck = scMod.Packages.AddNew("NVDB","")
						scPck.Update
						scMod.Packages.Refresh
						scPck.StereotypeEx="applicationSchema"
						scPck.Update
						'Legger på gml-tagger 
						dim tagVal as EA.TaggedValue
						set tagVal = Nothing
						set tagVal = scPck.Element.TaggedValues.AddNew("targetNamespace", ns)
						tagVal.Update()					
						set tagVal = scPck.Element.TaggedValues.AddNew("version", FC_version)
						tagVal.Update()
						set tagVal = scPck.Element.TaggedValues.AddNew("xmlns", "nvdb")
						tagVal.Update()
						set tagVal = scPck.Element.TaggedValues.AddNew("xsdDocument", nvn & ".xsd")
						tagVal.Update()
						set tagVal = scPck.Element.TaggedValues.AddNew("xsdEncodingRule", "sosi")
						tagVal.Update()
						scMod.Packages.Refresh
					
						'Importerer SOSI Fellesegenskaper-pakken
						Repository.WriteOutput "Script", Now & " Importerer SOSI Fellesegenskaper-pakken", 0 
						dim pI as EA.Project
						set pI = scRep.GetProjectInterface()
						pI.ImportPackageXMI scPck.PackageGUID, "C:\DATA\Standardisering\NVDB\NVDB Datakatalogen\trunk\public\SOSI Fellesegenskaper.xml", 1,0
								
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

						'Importerer aktuell objekttype sin pakke
						Repository.WriteOutput "Script", Now & " Importerer filen " & id & ".xml", 0 
						pI.ImportPackageXMI scPck.PackageGUID, svnSOSINVDBPath & FC_version & "\" & id & ".xml", 1,0
					
						'Løkke for assosiasjoner
						dim con as EA.Connector
						for each con in el.Connectors
							set tagVal = nothing
							set tagVal = con.TaggedValues.GetByName("NVDB_SupplierID")
							if not tagVal is nothing then
								if tagVal.Value <> id then
									'Importer assosiert pakke
									Repository.WriteOutput "Script", Now & " Importerer filen " & tagVal.Value & ".xml", 0 
									pI.ImportPackageXMI scPck.PackageGUID, svnSOSINVDBPath & FC_version & "\" & tagVal.Value & ".xml", 1,0
								end if
							end if
							set tagVal = nothing
							set tagVal = con.TaggedValues.GetByName("NVDB_ClientID")
							if not tagVal is nothing then
								if tagVal.Value <> id then
									'Importer assosiert pakke
									Repository.WriteOutput "Script", Now & " Importerer filen " & tagVal.Value & ".xml", 0 
									pI.ImportPackageXMI scPck.PackageGUID, svnSOSINVDBPath & FC_version & "\" & tagVal.Value & ".xml", 1,0
								end if
							end if
						next
						'scMod.Update
						scPck.Packages.Refresh
						
						'Legger til arv fra SOSI Fellesegenskaper for alle objekttyper
						dim ftSOSIfelles as EA.Element
						set ftSOSIfelles = pkSOSIfelles.Elements.GetByName("Fellesegenskaper")
			
						if not ftSOSIfelles is nothing then
							Repository.WriteOutput "Script", Now & " Elementet Fellesegenskaper funnet (" & ftSOSIfelles.ElementGUID & ")", 0 
							dim scSubPck as EA.Package
							for each scSubPck in scPck.Packages
								if scSubPck.PackageGUID <> pkSOSIfelles.PackageGUID then
									dim scEl as EA.Element
									for each scEl In scSubPck.elements
										if scEl.Stereotype="featureType" then
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
	
						'Rediger C:\DATA\GitHub\NVDBGML\runshapechange.bat
						Repository.WriteOutput "Script", Now & " Rediger runshapechange.bat", 0 
						dim objFS
						Set objFS = CreateObject("Scripting.FileSystemObject")
						dim strFile
						strFile = "C:\DATA\GitHub\NVDBGML\runshapechange.bat"
						dim objFile
						Set objFile = objFS.OpenTextFile(strFile)
						dim strLine
						strLine = objFile.ReadLine
						objFile.Close
						Set objFile = objFS.CreateTextFile(strFile, true)
						objFile.WriteLine(strLine)
						objFile.WriteLine("Mkdir C:\DATA\GitHub\NVDBGML\XSD\NVDB\" & id)
						objFile.WriteLine("Del /Q C:\DATA\GitHub\NVDBGML\XSD\NVDB\" & id & "\*.*")
						objFile.WriteLine("Move C:\DATA\GitHub\NVDBGML\XSD\INPUT\" & "*.* " & "C:\DATA\GitHub\NVDBGML\XSD\NVDB\" & id & "\")
						'objFile.WriteLine("Pause")
						'Close the file.
						objFile.Close
						Set objFile = Nothing
						'Kjør runshapechange.bat, vent på fullføring 		
						Repository.WriteOutput "Script", Now & " Kjører ShapeChange og flytter filer til riktig område...", 0 
						dim shell
						set shell=createobject("wscript.shell") 
						shell.run strFile, 1, true
						set shell=nothing
					
						'Hopp ut av løkka etter første pakke - fjernes når scriptet er ferdig.
						'scRep.CloseFile
						'scRep.Exit
						'Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
						'exit sub
						
						'Går ut av løkka, ettersom objekttypen er funnet. 
						j = pck.Elements.Count -1
					end if
				next
			end if	
		next
				
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
