!INC NVDB._parametre

'Generelle variabler
dim ePIF as EA.Project
dim modDakat as EA.Package
dim pkObjekttyper as EA.Package
dim pkDatatyper as EA.Package
dim pkNVDBSOSImain as EA.Package
dim pkSOSIFelles as EA.Package
dim pkSOSINVDB as EA.Package

dim modSOSI as EA.Package
dim eAttributt as EA.Attribute
dim eAttrNVDB as EA.Attribute
dim constraint as EA.Constraint

dim pkOT as EA.Package
dim pkOT_NVDB as EA.Package
dim pkOT_Sub as EA.Package

dim element as EA.Element
dim elNVDB as EA.Element
dim elementA as EA.Element
dim elementB as EA.Element
dim elementDT as EA.Element
dim elementCL as EA.Element
dim ftSOSIfelles as EA.Element
dim tagVal as EA.TaggedValue
dim aTag as EA.AttributeTag
dim con as EA.Connector
dim eDiagram As EA.Diagram
Dim eBDiagram As EA.Diagram
Dim eTVDiagram As EA.Diagram
Dim eASDiagram As EA.Diagram
Dim eHovedskjema As EA.Diagram
Dim diagramObjekt as EA.DiagramObject
Dim diagramLenke as EA.DiagramLink

dim dbDakat
dim rsDatatyper
dim rsObjekttyper
dim rsEgenskapstyper
dim rsKodelister
dim rsSammenhenger
dim geomPunkt
dim geomKurve

dim i
dim id 
dim idxe 
dim idxT
dim idxP
dim idxA
dim idxC
dim idxD
dim lstAlias 
dim lstSOSIelementNames
dim lstCodeListNames
dim lstNVDB
dim lstSOSI
dim lstNVDBpck
dim lstSOSIpck
dim lstNVDBot
dim lstSOSIot
Dim strAlias
Dim strStedfesting 
Dim retning 
Dim kjorefelt

'Generelle funksjoner

function connect2UMLmodels()
	outputTabs
	Repository.WriteOutput "Script", Now & " Kobler til modeller ", 0 
	set pkObjekttyper = Repository.GetPackageByGuid(guidNVDBVegobjekttyper)
	set pkSOSINVDB = Repository.GetPackageByGuid(guidSOSIDatakatalog)
	if pkObjekttyper is nothing and pkSOSINVDB is nothing then 
		connect2UMLmodels = false
		Repository.WriteOutput "Script", Now & " Feil ved tilkobling til modeller", 0 
	else
		connect2UMLmodels = true
		Repository.WriteOutput "Script", Now & " Tilkobling vellykket", 0 
	end if
end function

function outputTabs()
	'Faner for informasjon om kjøringen
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"
	Repository.CreateOutputTab "Endringer"
	Repository.ClearOutput "Endringer"
	Repository.CreateOutputTab "SOSI"
	Repository.ClearOutput "SOSI"
end function

function connect2models()
	'Setter opp kobling til modeller
	outputTabs
	
	Repository.WriteOutput "Script", Now & " Datakatalogversjon: " & FC_version, 0 
	Repository.WriteOutput "Script", Now & " Accessbase: " & FC_db, 0 
	Repository.WriteOutput "Script", Now, 0 
	Repository.WriteOutput "Script", Now & " Kobler til Datakatalog-accessdatabasen",0
    Dim strDakatAccessConnect
    strDakatAccessConnect = "Driver={Microsoft Access Driver (*.mdb)};" & "Dbq=" & FC_db & ";DefaultDir=;" & "Uid=Admin;Pwd=;"
	set dbDakat = CreateObject("ADODB.Connection")
    dbDakat.Open strDakatAccessConnect
	
	Repository.WriteOutput "Script", Now & " Setter opp modelltilknytninger",0
	
	set ePIF = Repository.GetProjectInterface
	set modDakat = Repository.Models.GetByName(strModelName)
	Repository.WriteOutput "Script", Now & " Hovedmodell for NVDB Datakatalogen: " & modDakat.Name,0
	set pkObjekttyper = modDakat.Packages.GetByName(strObjektPakke)
	Repository.WriteOutput "Script", Now & " Pakke med vegobjekttyper: " & pkObjekttyper.Name,0
    set pkDatatyper = modDakat.Packages.GetByName(strDatatypePakke)
	Repository.WriteOutput "Script", Now & " Pakke med NVDB-datatyper: " & pkDatatyper.Name,0
    set pkSOSIFelles = modDakat.Packages.GetByName(strSOSIFelles)
	Repository.WriteOutput "Script", Now & " Pakke med SOSI Fellesegenskaper: " & pkSOSIFelles.Name,0   
	set pkNVDBSOSImain = modDakat.Packages.GetByName(strNVDBSOSIPakke)
	Repository.WriteOutput "Script", Now & " Pakke med NVDB-SOSI-modeller: " & pkNVDBSOSImain.Name,0

	set modSOSI = Repository.Models.GetByName(strSOSIModell)
	Repository.WriteOutput "Script", Now & " Hovedmodell for SOSI: " & modSOSI.Name,0
	Repository.WriteOutput "Script", Now, 0 
	'dbDakat.Close
end function

Sub hideAttributes(eDobj)
	'Hide attributes for a diagramobject
	Dim strDOS
	strDOS = eDobj.Style
	If InStr(strDOS, "AttPub=1") > 0 Then
		eDobj.Style = Replace(strDOS, "AttPub=1", "AttPub=0")
	ElseIf InStr(strDOS, "AttPub=0") = 0 Then
		eDobj.Style = strDOS & "AttPub=0;"
	End If
	eDobj.Update()
End Sub

Sub setSize(eDobj, h, w)
	'Set size for diagram objects
	eDobj.bottom = eDobj.top - h
	eDobj.right = eDobj.left + w
	eDobj.Update()
End Sub

function getElementByAlias(pck, strAlias)
'Finner et angitt element i en pakke, ut fra alias
	Dim idx 
	set getElementByAlias = Nothing
	For idx = 0 To pck.Elements.Count - 1
		If (pck.Elements.GetAt(idx).Alias = strAlias) Then
			set getElementByAlias = pck.Elements.GetAt(idx)
			idx = pck.Elements.Count - 1
		End If
	Next
End Function

function getAttributeByAlias(el, strAlias)
'Finner en angitt attributt under et elementn , ut fra alias
	Dim idx 
	set getAttributeByAlias = Nothing
	For idx = 0 To el.Attributes.Count - 1
		If (el.Attributes.GetAt(idx).Alias = strAlias) Then
			set getAttributeByAlias = el.Attributes.GetAt(idx)
			idx = el.Attributes.Count - 1
		End If
	Next
End Function

Public Function createSOSInavn(str,ul,maxLength,delimiter)
	'Lager SOSI-navn av NVDB-navn
	
	dim strOrg
	strOrg = str 
	
	dim iFirst 
	iFirst = false
	
	With (New RegExp)
		.Global = True
		'Identifiserer de som starter med "I ", f.eks "I plan". Skal bli "iPlan", ikke "IPlan"
		If Left(str, 2) = "I " then
			iFirst = true
			'str = "i " &  Mid(str, 3)
			'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		End if	

		'Erstatter ">" med "Over"
		.Pattern = "[>]"
		str = .Replace(str, "-Over-") 
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "<" med "Under"
		.Pattern = "[<]"
		str = .Replace(str, "-Under-") 
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "%" med "Prosent"
		.Pattern = "[%]"
		str = .Replace(str, "-Prosent-") 
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "µm" med "Mikrometer"
		.Pattern = "µm"
		str = .Replace(str, "-Mikrometer-") 
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "km/t" med "kmt"
		.Pattern = "km/t"
		str = .Replace(str, "-kmt-") 
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "m.m." med "mm"
		.Pattern = ".m.m."
		str = .Replace(str, "-mm-")  
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "m/" og "M/" med "Med"
		.Pattern = "m/"
		str = .Replace(str, "-Med-") 
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		.Pattern = "M/"
		str = .Replace(str, "-Med-") 
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "u/" og "U/" med "Uten"
		.Pattern = "u/"
		str = .Replace(str, "-Uten-") 
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		.Pattern = "U/"
		str = .Replace(str, "-Uten-") 
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "(" og ")" med "Parentes" - byttes med "_" senere
		.Pattern = "[(]"
		str = .Replace(str, "-Parentes-") 
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		.Pattern = "[)]"
		str = .Replace(str, "-Parentes-")
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter " v " med "Ved"
		.Pattern = " v "
		str = .Replace(str, "-Ved-") 	
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter ":" mellom tall med "til". Eksempel: "10:1" blir "10til1"
		.Pattern = "([0-9]+)([:])([0-9]+)"
		str = .Replace(str, "$1til$3") 	
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "." mellom tall med "_". Eksempel: "1.5" blir "1_5"
		.Pattern = "([0-9]+)([.])([0-9]+)"
		str = .Replace(str, "$1_$3") 		
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "/" mellom tall med "_". Eksempel: "3/4" blir "3_4"
		.Pattern = "([0-9]+)([/])([0-9]+)"
		str = .Replace(str, "$1_$3") 		
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "-" mellom tall med "til". Eksempel: "3-4" blir "3til4"
		.Pattern = "([0-9]+)([-])([0-9]+)"
		str = .Replace(str, "$1til$3") 		
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter " - " mellom tall med "_". Eksempel: "BkT8 - 40 tonn" blir "bkT8_40Tonn"
		.Pattern = "([0-9]+)([\s][-][\s])([0-9]+)"
		str = .Replace(str, "$1_$3") 		
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter ".-" mellom tall med "til". Eksempel: "3.-4." blir "3til4"
		.Pattern = "([0-9]+)([.][-])([0-9]+)"
		str = .Replace(str, "$1til$3") 		
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "." mellom tall med "Punktum". Byttes med "_" senere. Eksempel: "1.5" blir "1Punktum5" og deretter "1_5"
		.Pattern = "([0-9]+)([.])([0-9]+)"
		str = .Replace(str, "$1-Punktum-$3") 
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "," mellom tall med "Komma". Byttes med "_" senere Eksempel: "1,5" blir "1Komma5" og deretter "1_5"
		.Pattern = "([0-9]+)([,])([0-9]+)"
		str = .Replace(str, "$1-Komma-$3") 		
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter " - " med "Mellomrom". Byttes med "_" senere. Eksempel: "Ord1 - Ord2" blir "Ord1_Ord2"
		.Pattern = "[\s][-][\s]"
		str = .Replace(str, "-Mellomrom-") 		
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter ", " mellom tall med "Mellomrom". Byttes med "_" senere Eksempel: Eksempel: "Ord1, Ord2" blir "Ord1_Ord2"
		.Pattern = "[,][\s]"
		str = .Replace(str, "-Mellomrom-") 		
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter " " mellom gjentakende store bokstaver med "Mellomrom". Byttes med "_" senere Eksempel: Eksempel: "ABC GF" blir "ABC_GF"
		.Pattern = "([A-Z_ÆØÅ][A-Z_ÆØÅ])+([ ])([A-Z_ÆØÅ][A-Z_ÆØÅ])"
		str = .Replace(str, "$1-Mellomrom-$3") 		
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "-" mellom gjentakende store bokstaver med "Mellomrom". Byttes med "_" senere Eksempel: Eksempel: "ABC-GF" blir "ABC_GF"
		.Pattern = "([A-Z_ÆØÅ][A-Z_ÆØÅ])+([-])([A-Z_ÆØÅ][A-Z_ÆØÅ])"
		str = .Replace(str, "$1-Mellomrom-$3") 		
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "-" generelt med "Mellomrom". Byttes med "_" senere Eksempel: Eksempel: "123-GF" blir "123_GF"
		.Pattern = "([a-zA-Z_0-9_æøå_ÆØÅ])([-])([a-zA-Z_0-9_æøå_ÆØÅ])" 
		str = .Replace(str, "$1-Mellomrom-$3") 
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter "ååååmmdd" med "-", dvs fjernes fra strengen
		.Pattern = "ååååmmdd"
		str = .Replace(str, "-") 	
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		'Erstatter ":" generelt med "Mellomrom". Byttes med "_" senere Eksempel: Eksempel: "123:GF" blir "123_GF"		
		.Pattern = ":"
		str = .Replace(str, "-Mellomrom-") 	
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		
		'Erstatte "tall mellomrom stor bokstav" og "stor bokstav mellomrom tall" med "$1-Mellomrom-$3"
		.Pattern = "([0-9])([ ])([A-Z_ÆØÅ])" 
		str = .Replace(str, "$1-Mellomrom-$3") 
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		.Pattern = "([A-Z_ÆØÅ])([ ])([0-9])" 
		str = .Replace(str, "$1-Mellomrom-$3") 
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
		
		'Erstatter gjenværende spesialtegn med "-", dvs de fjernes fra strengen.
		.Pattern = "[^a-zA-Z_0-9_æøå_ÆØÅ]" 
		str = .Replace(str, "-") 'all non-digits or letters replaced with "-"
		'Repository.WriteOutput "SOSI", Now & " " & str , 0 
	End With	
	
	Dim arr, i, strTmp
	strTmp = ""
	arr = Split(str, "-") 'create array with elements for each "-"
	For i = LBound(arr) To UBound(arr)
		if arr(i) <> "" then
			'Upper case for first letter in each new word
			arr(i) = UCase(Left(arr(i), 1)) & Mid(arr(i), 2)
			If arr(i) = "Parentes" or arr(i) = "Komma" or arr(i) = "Punktum" or arr(i) = "Mellomrom" then arr(i) = "_"
			strTmp = strTmp & arr(i)
			if i < Ubound (arr) and Right(arr(i),1) <> "_" then
				strTmp = strTmp & delimiter
			end if
		end if	
	Next

	With (New RegExp)
		.Global = True
		.Pattern = "[_]+"
		strTmp = .Replace(strTmp, "_") 
	End With	
	
	do while Right(strTmp,1) = "_"
		strTmp = Left(strTmp, len(strTmp)-1)
	loop
	
	if len(strTmp) > maxLength then
		strTmp = Left(strTmp, maxLength)
	end if
	
	if ul = "Lower" then
		'Lower case for first letter in complete word, unless both first and second letter i upper case
		'If so, the word is presumed to be a abbreviation, and the letters shall be kept upper case
		If iFirst = true or (not (UCase(Left(strTmp, 1)) = Left(strTmp, 1) and Ucase(Mid(strTmp, 2, 1)) = Mid(strTmp, 2, 1))) then
			strTmp = LCase(Left(strTmp, 1)) &  Mid(strTmp, 2)
		End if	
	end if
	
	createSOSInavn = strTmp
	Repository.WriteOutput "SOSI", Now & " Nytt SOSI-navn for " & strOrg & ": " & createSOSInavn , 0 
End Function

Sub sortElementsInPackage(p)
'Sortering av elementer i en pakke
	Dim lstEl 
	set lstEl = CreateObject("System.Collections.Sortedlist")
	Dim el As EA.Element
	For Each el In p.Elements
		Select Case el.Stereotype
			Case "featureType" : lstEl.Add "1." & el.Name, el.ElementID
			Case "Vegobjekttype" : lstEl.Add "1." & el.Name, el.ElementID
			Case "dataType" : lstEl.Add "2." & el.Name, el.ElementID
			Case "codeList" : lstEl.Add "3." & el.Name, el.ElementID
			Case "Tillatte verdier" : lstEl.Add "3." & el.Name, el.ElementID
			Case Else
				'writeLog(repDakat, "Datakatalog", el.Stereotype & "." & el.Name)
				'lstEl.Add "4." & el.name, el.ElementID			
		End Select
		'writeLog(repDakat, "Datakatalog", el.Stereotype & "." & el.Name)
	Next

	Dim i
	For i = 0 To lstEl.Count - 1
		set el = Repository.GetElementByID(lstEl.GetByIndex(i))
		el.TreePos = i + 1
		el.Update()
		Repository.WriteOutput "Script", Now & " Element: " & el.Name & " Ny posisjon: " & i , 0 
	Next
	set lstEl = Nothing
	'Repository.RefreshModelView(p.PackageID)

End Sub
