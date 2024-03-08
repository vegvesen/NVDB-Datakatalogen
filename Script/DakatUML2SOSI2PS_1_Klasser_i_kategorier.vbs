'option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

' Script Name: DakatUML2SOSI2PS_1_Klasser_i_kategorier
' Author: Knut Jetlund
' Purpose: Lager hovedpakke for  produktspesifikasjon for valgte vegobjekttypekategorier, ut fra koblingstabeller
' Date: 20210216
'

function ObjektlisteKlasser

	'Vise og tøm scriptvinduer
	outputTabs
	'Kobler til modell og database
	connect2models
	'Henter tabell for vegobjekttypekategorier
	set rsVOTKategorier = CreateObject("ADODB.Recordset")
	rsVOTKategorier.Open "SELECT * FROM VEGOB_TYPE_KAT", dbDakat, 3, 1
	'Lager koblingstabell for vegobjekttyper og vegobjekttypekategorier	
	set rsVTKat = CreateObject("ADODB.Recordset")
	rsVTKat.Open "SELECT * FROM KOPL_VOT_KAT", dbDakat, 3, 1
	
	'Hent valgt hovedpakke
	dim thePackage as EA.Package
	set thePackage = Repository.GetPackageByGuid(guidSOSIDatakatalog)
	'set thePackage = Repository.GetTreeSelectedPackage()
	Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 
	
	'Mulighet for å stoppe prosessen i tilfelle feil hovedpakke...
	'dim msgAnsw
	'if thePackage.Packages.Count > 0 then 
	'	msgAnsw = MsgBox("Slette gamle pakker fra hovedpakken " & thePackage.Name & "?", vbOkCancel, "Produktspesifikasjoner")
	'	if msgAnsw <> 2 then
	'		Repository.WriteOutput "Script", Now & " Sletter gamle pakker i hovedpakken...", 0 
	'		for idxP = 0 to thePackage.Packages.Count - 1
	'			set katPackage = thePackage.Packages.GetAt(idxP)
	'			Repository.WriteOutput "Script", Now & " Sletter pakken " & katPackage.Name & "...", 0 
	'			thePackage.Packages.DeleteAt idxP, 0
	'		next
	'		thePackage.Packages.Refresh
	'	else
	'		exit function
	'	end if	
	'end if	

	dim pI as EA.Project					
	set pI = Repository.GetProjectInterface()
	Set objFS = CreateObject("Scripting.FileSystemObject")

	'Filtrerer kategori-koblingstabeller 
	dim lstVOTK
	lstVOTK = Split(votkatId,",")
	dim vk
	for each vk in lstVOTK
		Repository.WriteOutput "Script", Now & " Vegobjekttypekategori: " &  vk,0
		rsVOTKategorier.Filter = "ID_VOBJ_TYP_KAT = " & VK
		
		'Lag ny PS-pakke for kategorien. Navn = Kategorinavn + Datakat-versjon
		dim katPackage as EA.Package
		Do Until rsVOTKategorier.EOF
			Repository.WriteOutput "Script", Now & " Vegobjekttypekategori: " & rsVOTKategorier.Fields("NAVN_VOBJ_TYP_KAT").Value & " (" & rsVOTKategorier.Fields("ID_VOBJ_TYP_KAT").Value & ")",0
			set katPackage = thePackage.Packages.AddNew(rsVOTKategorier.Fields("NAVN_VOBJ_TYP_KAT").Value,"Package") 'Add NV and SVV package to NVDB Datakatalogen
			katPackage.Update
			katPackage.StereotypeEx="applicationSchema"
			katPackage.Update
			set element = katPackage.Element
			'set tagVal = element.TaggedValues.AddNew("xsdDocument",rsVOTKategorier.Fields("kortn_VOBJ_TYP_KAT").Value)
			element.Alias = VK
			If rsVOTKategorier.Fields("BSKR_VOBJ_TYP_KAT").Value <> "" then element.Notes = rsVOTKategorier.Fields("BSKR_VOBJ_TYP_KAT").Value 'Hvis tredje kolonne VK_Beskrivelse ikke er tom.
			element.Update
			
			'Liste med GML-tagger til hovedpakke
			Set lstTags = CreateObject("System.Collections.SortedList")
			'targetnamespace fra kortnavn og versjonsnummer
			lstTags.Add "targetNamespace", strTargetNamespace & "/PS/" & rsVOTKategorier.Fields("kortn_VOBJ_TYP_KAT").Value & "/" & FC_version
			lstTags.Add "version", FC_version
			lstTags.Add "xmlns", "nvdb"
			'Skjemanavn fra kategorien sitt kortnavn
			lstTags.Add "xsdDocument", rsVOTKategorier.Fields("kortn_VOBJ_TYP_KAT").Value & ".xsd"

			'Legger på GML-tagger på hovedpakka. Litt komplekst pga tagger både i og utenfor UML-profil
			dim tagFound
			for idxT = 0 to lstTags.Count - 1
				dim tName
				tName = lstTags.GetKey(idxT)
				dim tValue
				tValue = lstTags.GetByIndex(idxT)

				tagFound = false
				for each tagVal in katPackage.Element.TaggedValues
					if tagVal.Name = tName then 
						tagVal.Value = tValue
						tagVal.Update
						tagFound= true
						Repository.WriteOutput "Script", Now & " Fant tagged value " & tagVal.Name & ", settes til " & tagVal.Value, 0 
					end if
				next
				if not tagFound then 
					Repository.WriteOutput "Script", Now & " Mangler tag " & tName, 0 
					set tagVal = katPackage.Element.TaggedValues.AddNew(tName, tValue)
					tagVal.Update
				end if
			next
			katPackage.Element.TaggedValues.Refresh
			
			'For hver VOT i kategorien:
			rsVTKat.Filter = "ID_VOBJ_TYP_KAT = " & vk
			Do Until rsVTKat.EOF
				'Importer VOT sin XMI, strip GUIDs
				dim strFileName
				strFileName = sosiPath & "\" & rsVTKat.Fields("ID_VOBJ_TYPE").Value & ".xml"
				if objFS.FileExists(strFileName) then

					Repository.WriteOutput "Script", Now & " Importerer Vegobjekttype-XMI: " & strFileName,0
					pI.ImportPackageXMI katPackage.PackageGUID, strFileName, 1,1
					katPackage.Packages.Refresh			

				end if
				rsVTKat.MoveNext()
			Loop	
			rsVOTKategorier.MoveNext()
		Loop
	next

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk resultatfilene...", 0 

end function
