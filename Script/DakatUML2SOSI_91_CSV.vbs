option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre
'
' Script Name: DakatUML2SOSI_91_CSV
' Author: Knut Jetlund
' Purpose: Eksporter mappingtabeller for NVDB
' Date: 20200618
'

dim dgr as EA.Diagram

dim objFSO, objFtFile, objPtFile, objEnFile, objRdfFile

sub exportMappingFiles()

	' Show and clear the script output window
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script" 
		
	set pkSOSINVDB = Repository.GetPackageByGuid(guidSOSIDatakatalog)
	Repository.WriteOutput "Script", Now & " Hovedpakke: " & pkSOSINVDB.Name & " (" & pkSOSINVDB.PackageGUID & ")", 0 
	
	Set objFSO=CreateObject("Scripting.FileSystemObject")
	Set objFtFile = CreateObject("ADODB.Stream")
	objFtFile.CharSet = "utf-8"
	objFtFile.Open
	Set objPtFile = CreateObject("ADODB.Stream")
	objPtFile.CharSet = "utf-8"
	objPtFile.Open
	Set objEnFile = CreateObject("ADODB.Stream")
	objEnFile.CharSet = "utf-8"
	objEnFile.Open
	'Set objRdfFile = CreateObject("ADODB.Stream")
	'objRdfFile.CharSet = "utf-8"
	'objRdfFile.Open
	
	objFtFile.WriteText "ftid;name" & vbCrLf
	objPtFile.WriteText "ft_attr;ftid;ptid;name" & vbCrLf
	objEnFile.WriteText "ptid;enid;name;fullname" & vbCrLf
	
	'objRdfFile.WriteText "<?xml version=""1.0"" encoding=""UTF-8""?>" & vbCrLf
	'objRdfFile.WriteText "<rdf:RDF " & vbCrLf
	'objRdfFile.WriteText "xmlns:rdf=""http://www.w3.org/1999/02/22-rdf-syntax-ns#"""  & vbCrLf
    'objRdfFile.WriteText "xmlns=""" & owlURI & """" & vbCrLf
    'objRdfFile.WriteText "xml:base=""" & owlURI & """>" & vbCrLf

	for each pkOT in pkSOSINVDB.Packages
		if pkOT.PackageGUID <> guidAbstrakteKlasser then 
			Repository.WriteOutput "Script", Now & " ------------------------------------------------------------------------------", 0 
			Repository.WriteOutput "Script", Now & " Vegobjekttypepakke: " & pkOT.Name, 0 

			for each element in pkOT.elements
				If UCase(element.Stereotype)="FEATURETYPE" then
					Repository.WriteOutput "Script", Now & " FeatureType: " & element.Name, 0 
					
					objFtFile.WriteText element.Alias & ";" & element.Name & vbCrLf

					'objRdfFile.WriteText "<rdf:Description rdf:about=""" & owlURI & "#ft" & element.Alias & """>" & vbCrLf
					'objRdfFile.WriteText "	<rdf:type rdf:resource=""" & owlURI & "#ft_mapping""/>" & vbCrLf
					'objRdfFile.WriteText "	<ftid rdf:datatype=""http://www.w3.org/2001/XMLSchema#integer"">" & element.Alias & "</ftid>" & vbCrLf
					'objRdfFile.WriteText "	<name_ft rdf:datatype=""http://www.w3.org/2001/XMLSchema#string"">" & element.Name & "</name_ft>" & vbCrLf
					'objRdfFile.WriteText "</rdf:Description>"  & vbCrLf		
					
					For each eAttributt in element.Attributes
						Repository.WriteOutput "Script", Now & " Attributt: " & eAttributt.Name, 0 
						objPtFile.WriteText "fme_feature_type;" & element.Alias & ";" & eAttributt.Alias & ";" & eAttributt.Name & vbCrLf			
					Next
				elseif UCase(element.Stereotype)="CODELIST" then
					Repository.WriteOutput "Script", Now & " Kodeliste: " & element.Name, 0 
					
					dim atv as EA.AttributeTag
					dim nvdb_navn
					
					For each eAttributt in element.Attributes
						set atv=eAttributt.TaggedValues.GetByName("NVDB_navn")
						nvdb_navn = ""
						if not atv is nothing then nvdb_navn=atv.Value
						
						if IsNull(eAttributt.Default) or eAttributt.Default = "" then
							Repository.WriteOutput "Script", Now & " Kodeverdi: " & eAttributt.Name, 0 
							objEnFile.WriteText element.Alias & ";" & eAttributt.Alias & ";" & eAttributt.Name & ";" & nvdb_navn & vbCrLf			
						else
							Repository.WriteOutput "Script", Now & " Kodeverdi: " & eAttributt.Default, 0 
							objEnFile.WriteText element.Alias & ";" & eAttributt.Alias & ";" & eAttributt.Default & ";" & nvdb_navn & vbCrLf			
						end if
						
						Repository.WriteOutput "Script", Now & " Attributt: " & eAttributt.Name, 0 
					Next
				
					
				
				end if
			next
	
		end if	
	next
		
	'objRdfFile.WriteText "</rdf:RDF>" & vbCrLf
	
	'objRdfFile.SaveToFile owlPath & "\" & "nvdb_gml_mapping.rdf", 2
	objFtFile.SaveToFile csvPath & "\" & "nvdb_ftMapping.csv", 2
	objPtFile.SaveToFile csvPath & "\" & "nvdb_ptMapping.csv", 2
	objEnFile.SaveToFile csvPath & "\" & "nvdb_enMapping.csv", 2
	
	objFtFile.Close
	objPtFile.Close
	objEnFile.Close
	'objRdfFile.Close
	
	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"
		
end sub

exportMappingFiles
