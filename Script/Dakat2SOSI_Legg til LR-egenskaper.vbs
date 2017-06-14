option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB._felles
!INC NVDB._parametre

'Legger til LR-egenskaper p� objekttyper i en pakkestruktur

sub addLRattr()

	'Setter opp kobling til modeller og databasetabell
	connect2models
	set rsObjekttyper = CreateObject("ADODB.Recordset")
	rsObjekttyper.Open "SELECT * FROM VEGOB_TYPE WHERE NAVN_VOBJ_TYPE NOT LIKE 'Utg�r%'", dbDakat, 3, 1
    rsObjekttyper.Filter = "Dato_fra_nvdb <> NULL"
    rsObjekttyper.MoveLast()

	'Get the currently selected package in the tree to work on
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
		
	For each pkOT_Sub in thePackage.Packages
		For each element in pkOT_Sub.Elements
			If element.Stereotype = "featureType" Or element.Stereotype = "FeatureType" Then	
				'm� lese stedfestingsinfo fra vegobjekttypetabell i Dakat, vha element.alias
				Repository.WriteOutput "Script", Now & " Oppdaterer objekttype: " & pkOT_Sub.name, 0

				rsObjekttyper.MoveFirst()
				rsObjekttyper.Find("ID_VOBJ_TYPE=" & element.Alias)
				If not rsObjekttyper.EOF Then
					dim strStedfesting
					strStedfesting = rsObjekttyper.Fields("Stedfesting").Value
					
					Select Case strStedfesting
						Case "strekning"
							'Legger til lr-posisjon for strekning
							Repository.WriteOutput "SOSI", Now & " Legger til egenskap line�rPosisjon (strekning) p� " & element.Name, 0
							set eAttributt = element.Attributes.AddNew("line�rPosisjon", "")
							eAttributt.Pos = 99999
							eAttributt.Type = "Line�rPosisjonStrekning"
							eAttributt.LowerBound = 0
							eAttributt.UpperBound = "*"
							eAttributt.Notes = "Angivelse av posisjon p� det line�re objektet."
							eAttributt.Visibility = "Public"
							set constraint = element.Constraints.AddNew("M� ha minst en av stedfestingene line�rPosisjon og senterlinje", "OCL")
							constraint.Notes = "inv:count(self.senterlinje)+count(self.line�rposisjon)>0"
							constraint.Weight = 100
							constraint.Update()
							set aTag = eAttributt.TaggedValues.AddNew("SOSI_navn", "LRSTREKNING")
							aTag.Update()
							set elementB = Nothing
							If blnFellesegenskaper Then
								'Finner kobling til riktig datatype i lokal pakke med SOSI Fellesegenskaper
								set elementB = pkSOSIfelles.Elements.GetByName(eAttributt.Type)
								If not elementB is Nothing then
									eAttributt.ClassifierID = elementB.ElementID
								End if
							Else
								'Finner kobling til riktig datatype
								set elementB = Repository.GetElementByGuid(guidLRStrekning)
								If not elementB is Nothing then
									eAttributt.ClassifierID = elementB.ElementID
								End if	
							End If
							eAttributt.Update()
								
						Case "punkt"
							'Legger til lr-posisjon for punkt
							Repository.WriteOutput "SOSI", Now & " Legger til egenskap line�rPosisjon (punkt) p� " & element.Name, 0
							set eAttributt = element.Attributes.AddNew("line�rPosisjon", "")
							eAttributt.Pos = 99999
							eAttributt.Type = "Line�rPosisjonPunkt"
							eAttributt.LowerBound = 0
							eAttributt.UpperBound = "*"
							eAttributt.Notes = "Angivelse av posisjon p� det line�re objektet."
							eAttributt.Visibility = "Public"
							set constraint = element.Constraints.AddNew("M� ha minst en av stedfestingene line�rPosisjon og posisjon", "OCL")
							constraint.Notes = "inv:count(self.posisjon)+count(self.line�rPosisjon)>0"
							constraint.Weight = 100
							constraint.Update()
							set aTag = eAttributt.TaggedValues.AddNew("SOSI_navn", "LRPUNKT")
							aTag.Update()
							set elementB = Nothing
							If blnFellesegenskaper Then
								'Finner kobling til riktig datatype i lokal pakke med SOSI Fellesegenskaper
								set elementB = pkSOSIfelles.Elements.GetByName(eAttributt.Type)
								If not elementB is Nothing then
									eAttributt.ClassifierID = elementB.ElementID
								End if	
							Else
								'Finner kobling til riktig datatype								
								set elementB = Repository.GetElementByGuid(guidLRPunkt)
								if not elementB is Nothing then
									eAttributt.ClassifierID = elementB.ElementID
								End if	
							End If
							eAttributt.Update()
					End Select			
				End if	
			End if
		Next
	Next

	Repository.WriteOutput "Script", Now & " Ferdig, sjekk logg", 0 
	Repository.EnsureOutputVisible "Script"
	'Repository.RefreshModelView(pkNVDBSOSImain.PackageID)

end sub

addLRattr
