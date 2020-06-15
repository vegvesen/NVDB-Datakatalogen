option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre
!INC NVDB til SOSI.DakatUML2SOSI2GML_0_Fellesskjema

' Script Name: DakatUML2SOSI2GML_0_VEgobjekttyper
' Author: Knut Jetlund
' Purpose: Generer applikasjonsskjema for hver vegobjekttype
' Date: 20200606
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
	Set objFS = CreateObject("Scripting.FileSystemObject")
		
	if not thePackage is nothing and thePackage.ParentID <> 0 then
		Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 
		dim pck as EA.Package

		'Løkke for kjøring pr vegobjekttype
		for each pck in thePackage.Packages
			if pck.Alias <> "532" and pck.PackageGUID <> guidAbstrakteKlasser then 'Vegreferanse skal ikke være med
				Repository.WriteOutput "Script", Now & " ", 0 
				Repository.WriteOutput "Script", Now & " Lager applikasjonsskjemamodell for delpakken " & pck.Name & " (" & pck.PackageGUID & ")", 0 

				'Liste med GML-tagger til hovedpakke
				Set lstTags = CreateObject("System.Collections.SortedList")
				lstTags.Add "targetNamespace", strTargetNamespace
				lstTags.Add "version", FC_version
				lstTags.Add "xmlns", "nvdb"
				lstTags.Add "xsdDocument", pck.Alias & ".xsd"

				'Lager modell og hovedpakke
				createSCmodel
				'Importerer Abstrakte klasser-pakken til modellen ShapeChange
				importAbstrakteKlasser
				set tagVal = absClasses.Element.TaggedValues.AddNew("xsdDocument", "AbstraktNVDB.xsd")
				tagVal.Update				

				'Importerer aktuell objekttype sin pakke til modellen ShapeChange
				Repository.WriteOutput "Script", Now & " Importerer pakke for hovedobjekttypen " & pck.Name & " (fil: " & sosiPath & "\" & pck.Alias & ".xml)", 0 
				set pI = scRep.GetProjectInterface()
				pI.ImportPackageXMI scPck.PackageGUID, sosiPath & "\" & pck.Alias & ".xml", 1,0
				scPck.Packages.Refresh			

				'Fjerner eventuelle targetNamespace-tagger på delpakker
				dim scSubPck as EA.Package
				for each scSubPck in scPck.Packages
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
							for each element in scSubPck.Elements
								'Sletter alle constraints
								for idxC = 0 to element.Constraints.Count - 1
									element.Constraints.DeleteAt idxC, false
								next
								element.Constraints.Refresh											
							next
						end if
					next
					scSubPck.Element.TaggedValues.Refresh
				next	 

				'Fjerner alle andre abstrakte klasser enn den som tilhører hovedobjekttypen, for lettere ShapeChange-kjøring
				For idxe = 0 to absClasses.Elements.Count -1
					set element = absClasses.Elements.GetAt(idxe)
					if UCase(element.Stereotype) = "FEATURETYPE" and element.Alias <> pck.Alias then 
						Repository.WriteOutput "Script", Now & " Sletter abstrakt klasse: " & element.Name, 0 
						absClasses.Elements.DeleteAt idxe, false
					end if						
				next	
				absClasses.Elements.Refresh	
				
				'Kjører ShapeChange, venter på fullføring
				runSC							

				'Flytter pakken sin skjemafil til riktig område
				moveFile pck.Alias & ".xsd", scPath & "\XSD\INPUT\",gmlPath & "\"

				'Close SC
				scRep.CloseFile
				scRep.Exit
				set scRep = nothing	

				'Mulighet for å hoppe ut av løkka - fjernes når scriptet er ferdig.
				'msgAnsw = MsgBox("Sjekk SC-modellen nå", vbOkCancel, "GML-applikasjonsskjema")
				'if msgAnsw = 2 then
				'	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
				'	exit sub
				'end if	

			end if
		next	
	end if
	
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 
	Repository.EnsureOutputVisible "Script"

end sub

main