option explicit

!INC Local Scripts.EAConstants-VBScript

'
' Script Name: Export mapping files
' Author: Knut Jetlund
' Purpose: Export mapping files from GML to NVDB
' Date: 20150508
'

dim dgr as EA.Diagram

dim objFSO, objFtFile, objPtFile, objEnFile

sub recLoopSubPackages(p)
	Session.Output(Now & " Package: " & p.Name)
	dim e as EA.Element
	dim a as EA.Attribute
	dim tv as EA.TaggedValue
	dim atv as EA.AttributeTag
	dim nvdb_id, nvdb_navn
	
	for each e in p.elements
	   If e.Stereotype="featureType" then
			set tv=e.TaggedValues.GetByName("NVDB_ID")
			if not tv is nothing then
				objFtFile.Write tv.Value & ";" & e.Name & vbCrLf
				for each a in e.Attributes
					set atv=nothing
					On error resume next
					set atv=a.TaggedValues.GetByName("NVDB_ID")
					if not atv is nothing then
						Session.Output(Now & " Attribute: " & a.Name)
						objPtFile.Write "fme_feature_type;" & tv.Value & ";" & atv.Value & ";" & a.Name & vbCrLf
					end if	
				next
			end if	
		elseif e.Stereotype="codeList" then
			set tv=e.TaggedValues.GetByName("NVDB_ID")
			if not tv is nothing then
				for each a in e.Attributes
					set atv=nothing
					On error resume next
					set atv=a.TaggedValues.GetByName("NVDB_ID")
					if not atv is nothing then nvdb_id=atv.Value
					set atv=a.TaggedValues.GetByName("NVDB_navn")
					if not atv is nothing then nvdb_navn=atv.Value
					
					if IsNull(a.Default) or a.Default = "" then
						Session.Output(Now & " Code value: " & a.Name)
						objEnFile.Write tv.Value & ";" & nvdb_id & ";" & a.Name & ";" & nvdb_navn & vbCrLf 
					else
						Session.Output(Now & " Code value: " & a.Name & "(" & a.Default & ")")
						objEnFile.Write tv.Value & ";" & nvdb_id & ";" & a.Default & ";" & nvdb_navn & vbCrLf 
					end if
				next
			end if	
		end if
	next
	
	
	dim subP as EA.Package
	for each subP in p.packages
	    recLoopSubPackages(subP)
	next
end sub

'Find selected package, and start loop through package and subpackages
sub exportMappingFiles()

	' Show and clear the script output window
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script" 
		
	set pkSOSINVDB = Repository.GetPackageByGuid(guidSOSIDatakatalog)		
	dim tv as EA.TaggedValue
	set tv=pkSOSINVDB.Element.TaggedValues.GetByName("xsdDocument")
	dim name 
	name=Replace(tv.value,".xsd","")

	Set objFSO=CreateObject("Scripting.FileSystemObject")
	Set objFtFile = objFSO.CreateTextFile(csvPath & "\" & name & "_ftMapping.csv",True)
	Set objPtFile = objFSO.CreateTextFile(csvPath & "\" & name & "_ptMapping.csv",True)
	Set objEnFile = objFSO.CreateTextFile(csvPath & "\" & name & "_enMapping.csv",True)
	
	objFtFile.Write "ftid;name" & vbCrLf
	objPtFile.Write "ft_attr;ftid;ptid;name" & vbCrLf
	objEnFile.Write "ptid;enid;name;fullname" & vbCrLf
	
	recLoopSubPackages(pkSOSINVDB)
	
	objFtFile.Close
	objPtFile.Close
	objEnFile.Close

	Session.Output(Now & " Ferdig!" )
		
end sub

exportMappingFiles
