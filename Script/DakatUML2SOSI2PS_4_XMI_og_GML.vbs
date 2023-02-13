'option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

' Script Name: DakatUML2SOSI2PS_4_XMI_og_GML
' Author: Knut Jetlund
' Purpose: Eksport av XMI-filer og generering av GML-applikasjonsskjema for produktspesifikasjoner basert på vegkategorier
' Date: 20210219
'

function ObjektlisterExport

	'Vise og tøm scriptvinduer
	outputTabs
	'Kobler til modell og database
	connect2models

	'Hent valgt hovedpakke
	dim thePackage as EA.Package
	set thePackage = Repository.GetPackageByGuid(guidSOSIDatakatalog)
	'set thePackage = Repository.GetTreeSelectedPackage()
	Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 
	
	dim pI as EA.Project					
	Set objFS = CreateObject("Scripting.FileSystemObject")

	dim katPackage as EA.Package
	for each katPackage in thePackage.Packages
	
		if (katPackage.Alias = "303" or katPackage.Alias = "304") and UCase(katPackage.Name) <> "UNDERGRUNN" then
			Repository.WriteOutput "Script", Now & " Pakke for kategori: " & katPackage.Name & " (" & katPackage.Alias & ")", 0  

			'Finner filnavn
			dim strName, strXMI, tagFound
			tagFound = false
			for each tagVal in katPackage.Element.TaggedValues
				if tagVal.Name = "xsdDocument" then 
					strName = Replace(tagVal.Value, ".xsd","")
					strXMI = sosiPath & "\" & strName & ".xml"
					Repository.WriteOutput "Script", Now & " Fant tagged value " & tagVal.Name & ", XMI-filnavn settes til " & strXMI, 0 
					tagFound = true
				end if
			next
			if not tagFound then 
				Repository.WriteOutput "Script", Now & " Mangler tag " & tName, 0 
				exit function
			end if


			'Eksporter XMI-fil
			set pI = Repository.GetProjectInterface()
			Repository.WriteOutput "Script", Now & " Eksporter filen " & strXMI, 0 
			pI.ExportPackageXMI katPackage.PackageGUID, 12, 1, -1, 1, 0, strXMI		
			
			'Lager ShapeChange-prosjektet
			Repository.WriteOutput "Script", Now & " Lager ShapeChange-prosjektet " & scPath & "\" & scProject, 0 
			'Sletter eventuelt gammel fil
			If objFS.FileExists(scPath & "\" & scProject) then objFS.DeleteFile scPath & "\" & scProject, true
			set scRep = CreateObject("EA.Repository")
			scRep.CreateModel cmEAPFromBase, scPath & "\" & scProject,1
			scRep.OpenFile(scPath & "\" & scProject)
			Repository.WriteOutput "Script", Now & " Lager modellen ShapeChange", 0 
			set scMod = scRep.Models.AddNew("ShapeChange","")
			scMod.Update	
			scRep.Models.Refresh	
			'Importerer XMI-fil
			set pI = scRep.GetProjectInterface()
			Repository.WriteOutput "Script", Now & " Importerer pakken " & katPackage.Name & " (" & strXMI & ")", 0 
			pI.ImportPackageXMI scMod.PackageGUID, strXMI, 1,0

			'Fjern alle constraints, for penere logfil
			dim kPck as EA.Package
			dim vPck as EA.Package
			dim el as EA.Element
			for each kPck in scMod.Packages
				'Bytter navn til NVDB for hovedpakken (som definert i ShapeChangeConfiguration.xml)
				kPck.Name = "NVDB"
				kPck.Update
				for each vPck in kPck.Packages
					Repository.WriteOutput "Script", Now & " Sletter constraints i pakken " & vPck.Name, 0 			
					for each el in vPck.Elements
						'Sletter alle constraints
						for idxC = 0 to el.Constraints.Count - 1
							el.Constraints.DeleteAt idxC, false
						next
						el.Constraints.Refresh
					next
				next
			next

			scRep.CloseFile
			scRep.Exit
			set scRep = nothing	

			'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
			dim msgAnsw
			'msgAnsw = MsgBox("Sjekk status", vbOkCancel, "Script")
			'if msgAnsw = 2 then
			'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
			'	exit function
			'end if	|


			'Kjører ShapeChange, venter på fullføring
			runSC	
					
			'TODO: Lag mappestruktur og flytt filer
			dim strFolder
			strFolder = gmlPath & "\PS" 
			if not objFS.FolderExists(strFolder) then objFS.CreateFolder strFolder
			strFolder = strFolder & "\" & strName
			if not objFS.FolderExists(strFolder) then objFS.CreateFolder strFolder
			strFolder = strFolder & "\" & FC_version
					
			if objFS.FolderExists(strFolder) then
				Repository.WriteOutput "Script", Now & " Mappen " & strFolder & " finnes fra før slettes", 0 
				objFS.DeleteFolder strFolder
			else
				Repository.WriteOutput "Script", Now & " Mappen finnes ikke fra før", 0 
			end if
			Repository.WriteOutput "Script", Now & " Oppretter mappen " & strFolder, 0 
			objFS.CreateFolder strFolder
			'Flytter filer
			Repository.WriteOutput "Script", Now & " Flytter filer fra " & scPath & "\XSD\INPUT\*.xsd" & " til " & strFolder, 0 
			objFS.MoveFile scPath & "\XSD\INPUT\*.xsd", strFolder & "\"

			'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
			'msgAnsw = MsgBox("Sjekk status", vbOkCancel, "Script")
			'if msgAnsw = 2 then
			'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
			'	exit function
			'end if	
		else 
			Repository.WriteOutput "Script", Now & " " & katPackage.Name & " (" & katPackage.Alias & ")" & " is not a Kategoripakke -- jumping to next one.", 0
		end if
			
	next

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 

end function

