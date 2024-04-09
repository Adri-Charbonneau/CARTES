$bdd_codes = Import-Csv "BDD-CODES.csv"
"INPN","INATURALIST","OBSERVATION","GBIF" | foreach $_{ New-Item -ItemType directory -Name $("\temp\" + $_) } | Out-Null

$bdd_codes | ForEach-Object -Parallel {
	$bdd_nom = $_.BDD_NOM
	$bdd_min = $_.BDD_MIN
	$icon = $_.ICON
	$bdd_url = $_.BDD_URL
	
	### CREATION DES CSV - INPN
	if ($bdd_nom -eq "INPN") {
		# Test API
		$INPN_url = (Invoke-WebRequest -Uri 'https://openobs.mnhn.fr/biocache-service/occurrences/search' -SkipHttpErrorCheck -ErrorAction Stop).BaseResponse
		
		if ($INPN_url.StatusCode -eq "OK") {
			$cigales_codes = Import-Csv "CIGALES-CODES.csv"
			
			$cigales_codes | ForEach-Object {
				$code = $_.CODE
				$nom = $_.NOM_SCIENTIFIQUE
				$faune_france = $_.FAUNE_FRANCE
				$inpn = $_.INPN
				$wad = $_.WAD
				$inaturalist = $_.INATURALIST
				$observation = $_.OBSERVATION
				$gbif = $_.GBIF
				$col = $_.CATALOGUE_OF_LIFE
				$fauna_europea = $_.FAUNA_EUROPEA
				
				"INPN - $nom"
				if ($inpn -eq "") {
					"  > L'espèce n'existe pas dans INPN"
					Add-Content "./temp/INPN/$code.csv" "Latitude,Longitude,ID,Date"
				}
				else {
					$trurl = 'https://openobs.mnhn.fr/biocache-service/occurrences/search?q=taxonConceptID:' + $inpn +' AND ((dynamicProperties_nivValNationale:"Certain - très probable") OR (dynamicProperties_nivValNationale:"Probable") OR (dynamicProperties_nivValNationale:"Non réalisable")) AND ((dynamicProperties_nivValRegionale:"Certain - très probable") OR (dynamicProperties_nivValRegionale:"Probable") OR (dynamicProperties_nivValRegionale:"Non réalisable") OR (*:* dynamicProperties_nivValRegionale:*))'
					$totalRecords = (Invoke-WebRequest $trurl | ConvertFrom-Json).totalRecords
					if ($totalRecords -eq 0) {
						"  > L'espèce est présente dans INPN mais ne possède aucune donnée" 
						Add-Content "./temp/INPN/$code.csv" "Latitude,Longitude,ID,Date"
					}
					else {
						Add-Content "./temp/INPN/$code-coord.csv" "Latitude,Longitude"
						Add-Content "./temp/INPN/$code-id.csv" "ID"
						Add-Content "./temp/INPN/$code-date.csv" "Date"
						$pages = [math]::floor($totalRecords/300)
						for ($num=0;$num -le $pages;$num++) {
							if ($num -eq 0) {$startIndex=0} else {$startIndex = ($num*300)}
							#$startIndex
							#"page $num sur $pages"
							$jsonurl = $trurl + '&startIndex=' + $startIndex + '&pageSize=300'
							$json = (Invoke-WebRequest $jsonurl | ConvertFrom-Json)
							$json_filter = $json.occurrences -match "latLong" # Vérification de la présence de coordonnées
							$latLong = $json_filter.latLong | Add-Content "./temp/INPN/$code-coord.csv"
							$id = $json_filter.uuid | Add-Content "./temp/INPN/$code-id.csv"
							
							# date
							$timestamp = $json_filter.eventDate
							foreach ($time in $timestamp) {
								$datetime = [datetimeoffset]::FromUnixTimeMilliseconds($time).DateTime
								$datetime.ToString('yyyy-MM-dd') | Add-Content "./temp/INPN/$code-date.csv"
							}
							
							# vérifier la cohérence avec $month et $year
						}
						
						$coord = Get-content "./temp/INPN/$code-coord.csv" 
						$id = Get-content "./temp/INPN/$code-id.csv"
						$date = Get-content "./temp/INPN/$code-date.csv"
						$(for($index=0;$index -lt $coord.Count;$index++){$coord[$index] + "," + $id[$index] + "," + $date[$index]}) | Add-Content "./temp/INPN/$code.csv"
						(Get-Content "./temp/INPN/$code.csv") | ? {$_.trim() -ne "" } | Set-Content "./temp/INPN/$code.csv"
						
						Remove-item "./temp/INPN/$code-coord.csv"
						Remove-item "./temp/INPN/$code-id.csv"
						Remove-item "./temp/INPN/$code-date.csv"
					}
				}
			}
			
			} else {
			"  > L'API de l'INPN est inaccessible"
		}	
	} # FIN INPN
	
	### CREATION DES CSV - INATURALIST
	if ($bdd_nom -eq "INATURALIST") {
		# Test API
		$INATURALIST_url = (Invoke-WebRequest -Uri 'https://api.inaturalist.org/v1/docs/' -SkipHttpErrorCheck -ErrorAction Stop).BaseResponse
		
		if ($INATURALIST_url.StatusCode -eq "OK") {
			$cigales_codes = Import-Csv "CIGALES-CODES.csv"
			
			$cigales_codes | ForEach-Object {
				$code = $_.CODE
				$nom = $_.NOM_SCIENTIFIQUE
				$faune_france = $_.FAUNE_FRANCE
				$inpn = $_.INPN
				$wad = $_.WAD
				$inaturalist = $_.INATURALIST
				$observation = $_.OBSERVATION
				$gbif = $_.GBIF
				$col = $_.CATALOGUE_OF_LIFE
				$fauna_europea = $_.FAUNA_EUROPEA
				
				"Inaturalist - $nom"
				
				if ($inaturalist -eq "") {
					"  > L'espèce n'existe pas dans Inaturalist"
					Add-Content "./temp/INATURALIST/$code.csv" "Latitude,Longitude,ID,Date"
				}
				else {
					$total_results = (Invoke-WebRequest "https://api.inaturalist.org/v1/observations?&place_id=6753&taxon_id=$inaturalist" | ConvertFrom-Json).total_results
					if ($total_results -eq 0) {
						"  > L'espèce est présente dans Inaturalist mais ne possède aucune donnée"
						Add-Content "./temp/INATURALIST/$code.csv" "Latitude,Longitude,ID,Date"		
					}
					else {
						Add-Content "./temp/INATURALIST/$code-coord.csv" "Latitude,Longitude"
						Add-Content "./temp/INATURALIST/$code-id.csv" "ID"
						Add-Content "./temp/INATURALIST/$code-date.csv" "Date"
						
						$pages = [math]::ceiling($total_results/200)
						for ($num=1;$num -le $pages;$num++) {
							#"page $num sur $pages"
							$json = (Invoke-WebRequest "https://api.inaturalist.org/v1/observations?&place_id=6753&taxon_id=$inaturalist&page=$num&per_page=200" | ConvertFrom-Json)
							$json_filter = $json.results | where {$_.quality_grade -ne "needs_id"} # Observation au moins validée par une personne
							$json_filter.location | Add-Content "./temp/INATURALIST/$code-coord.csv" 
							$json_filter.id | Add-Content "./temp/INATURALIST/$code-id.csv"
							$json_filter.observed_on | Add-Content "./temp/INATURALIST/$code-date.csv" 
						}		
						
						$coord = Get-content "./temp/INATURALIST/$code-coord.csv" 
						$id = Get-content "./temp/INATURALIST/$code-id.csv"
						$date = Get-content "./temp/INATURALIST/$code-date.csv"
						$(for($index=0;$index -lt $coord.Count;$index++){$coord[$index] + "," + $id[$index] + "," + $date[$index]}) | Add-Content "./temp/INATURALIST/$code.csv"
						(Get-Content "./temp/INATURALIST/$code.csv") | ? {$_.trim() -ne "" } | Set-Content "./temp/INATURALIST/$code.csv"
						
						Remove-item "./temp/INATURALIST/$code-coord.csv"
						Remove-item "./temp/INATURALIST/$code-id.csv"
						Remove-item "./temp/INATURALIST/$code-date.csv"
					}
				}
			}
			
			} else {
			"  > L'API d'iNaturalist est inaccessible"
		}
	} # FIN INATURALIST
	
	### CREATION DES CSV - OBSERVATION
	if ($bdd_nom -eq "OBSERVATION") {
		# Test API
		$OBSERVATION_url = (Invoke-WebRequest -Uri 'https://observation.org/api/v1/docs/' -SkipHttpErrorCheck -ErrorAction Stop).BaseResponse
		
		if ($OBSERVATION_url.StatusCode -eq "OK") {
			$cigales_codes = Import-Csv "CIGALES-CODES.csv"
			### AUTHENTIFICATION
			$OBS_TOKEN = (Invoke-WebRequest -Uri "https://observation.org/api/v1/oauth2/token/" -Method POST -Body $params | ConvertFrom-Json).access_token
			$OBS_HEADERS = @{Authorization="Bearer $OBS_TOKEN"}
			
			$cigales_codes | ForEach-Object {
				$code = $_.CODE
				$nom = $_.NOM_SCIENTIFIQUE
				$faune_france = $_.FAUNE_FRANCE
				$inpn = $_.INPN
				$wad = $_.WAD
				$inaturalist = $_.INATURALIST
				$observation = $_.OBSERVATION
				$gbif = $_.GBIF
				$col = $_.CATALOGUE_OF_LIFE
				$fauna_europea = $_.FAUNA_EUROPEA
				
				"Observation.org - $nom"
				
				if ($observation -eq "") {
					"  > L'espèce n'existe pas dans Observation.org"
					Add-Content "./temp/OBSERVATION/$code.csv" "Latitude,Longitude,ID,Date"
				}
				else {
					$count = (Invoke-WebRequest "https://observation.org/api/v1/species/$observation/observations/?country_id=78" -Headers $OBS_HEADERS | ConvertFrom-Json).count
					if ($count -eq 0)  {
						"  > L'espèce est présente dans Observation.org mais ne possède aucune donnée"
						Add-Content "./temp/OBSERVATION/$code.csv" "Latitude,Longitude,ID"
					}
					else {
						Add-Content "./temp/OBSERVATION/$code.csv" "Latitude,Longitude,ID,Date"
						$pages = [math]::floor($count/300)
						for ($num=0;$num -le $pages;$num++) {
							if ($num -eq 0) {$offset=0} else {$offset = ($num*300)}
							#$offset
							#"page $num sur $pages"
							$json = (Invoke-WebRequest "https://observation.org/api/v1/species/$observation/observations/?country_id=78&offset=$offset&limit=300" -Headers $OBS_HEADERS  | ConvertFrom-Json)
							$json_filter = $json.results | where {$_.is_certain -eq "True"} # Observation certaine
							$json_valid = $json_filter | where { ($_.validation_status -ne "I") -and ($_.validation_status -ne "N") } # Observation pas en attente ou invalide
							$json_end = $json_valid | where {$_.number -gt 0} # Effectif supérieur à 0
							For ($i=0; $i -le (($json_end.Length)-1); $i++) {
								$lat = $json_end[$i].point.coordinates[1]
								$long = $json_end[$i].point.coordinates[0]
								$id = $json_end[$i].id
								$date = $json_end[$i].date
								$value = "$($lat),$($long),$($id),$($date)"
								$value | Add-Content "./temp/OBSERVATION/$code.csv"
							}
						}
					}
				}
			}
			
			} else {
			"  > L'API d'Observation.org est inaccessible"
		}
	} # FIN OBSERVATION
	
	### CREATION DES CSV - GBIF
	if ($bdd_nom -eq "GBIF") {
		# Test API
		$GBIF_url = (Invoke-WebRequest -Uri 'https://api.gbif.org/v1/occurrence/search' -SkipHttpErrorCheck -ErrorAction Stop).BaseResponse
		
		if ($GBIF_url.StatusCode -eq "OK") {
			$cigales_codes = Import-Csv "CIGALES-CODES.csv"
			
			$cigales_codes | ForEach-Object {
				$code = $_.CODE
				$nom = $_.NOM_SCIENTIFIQUE
				$faune_france = $_.FAUNE_FRANCE
				$inpn = $_.INPN
				$wad = $_.WAD
				$inaturalist = $_.INATURALIST
				$observation = $_.OBSERVATION
				$gbif = $_.GBIF
				$col = $_.CATALOGUE_OF_LIFE
				$fauna_europea = $_.FAUNA_EUROPEA
				
				"GBIF - $nom"
				
				if ($GBIF -eq "") {
					"  > L'espèce n'existe pas dans GBIF"
					Add-Content "./temp/GBIF/$code.csv" "Latitude,Longitude,ID,Date"
				}
				else {
					$count = (Invoke-WebRequest "https://api.gbif.org/v1/occurrence/search?country=FR&taxon_key=$gbif&occurrenceStatus=PRESENT" | ConvertFrom-Json).count
					if ($count -eq 0)  {
						"  > L'espèce est présente dans GBIF mais ne possède aucune donnée"
						Add-Content "./temp/GBIF/$code.csv" "Latitude,Longitude,ID,Date"
					}
					else {
						Add-Content "./temp/GBIF/$code-coord.csv" "Latitude,Longitude"
						Add-Content "./temp/GBIF/$code-id.csv" "ID"
						Add-Content "./temp/GBIF/$code-date.csv" "Date"
						
						$pages = [math]::floor($count/300)
						for ($num=0;$num -le $pages;$num++) {
							if ($num -eq 0) {$offset=0} else {$offset = ($num*300)}
							#$offset
							#"page $num sur $pages"
							$json = (Invoke-WebRequest "https://api.gbif.org/v1/occurrence/search?country=FR&taxon_key=$gbif&occurrenceStatus=PRESENT&offset=$offset&limit=300" | ConvertFrom-Json)
							$json_filter = $json.results | where { ($_.identificationVerificationStatus -ne "Douteux") -and ($_.identificationVerificationStatus -ne "Invalide") } # Observation non douteuse ou invalide
							$json_filter = $json_filter -match "decimalLatitude" # Vérification de la présence de coordonnées
							$lat = $json_filter.decimalLatitude | Add-Content "./temp/GBIF/$code-lat.csv" 
							$long = $json_filter.decimalLongitude | Add-Content "./temp/GBIF/$code-long.csv" 
							$id = $json_filter.key | Add-Content "./temp/GBIF/$code-id.csv" 
							$date = $json_filter.eventDate -replace '(.*?)T(.*?)$','$1' | Add-Content "./temp/GBIF/$code-date.csv" 
						}
						
						$lat = Get-content "./temp/GBIF/$code-lat.csv" 
						$long = Get-content "./temp/GBIF/$code-long.csv" 
						$(for($index=0;$index -lt $lat.Count;$index++){$lat[$index] + "," + $long[$index]}) | Add-Content "./temp/GBIF/$code-coord.csv"
						(Get-Content "./temp/GBIF/$code-coord.csv") | ? {$_.trim() -ne "" } | Set-Content "./temp/GBIF/$code-coord.csv"
						Remove-item "./temp/GBIF/$code-lat.csv" 
						Remove-item "./temp/GBIF/$code-long.csv" 
						
						$coord = Get-content "./temp/GBIF/$code-coord.csv" 
						$id = Get-content "./temp/GBIF/$code-id.csv"
						$date = Get-content "./temp/GBIF/$code-date.csv"
						$(for($index=0;$index -lt $coord.Count;$index++){$coord[$index] + "," + $id[$index] + "," + $date[$index]}) | Add-Content "./temp/GBIF/$code.csv"
						(Get-Content "./temp/GBIF/$code.csv") | ? {$_.trim() -ne "" } | Set-Content "./temp/GBIF/$code.csv"
						
						Remove-item "./temp/GBIF/$code-coord.csv"
						Remove-item "./temp/GBIF/$code-id.csv"
						Remove-item "./temp/GBIF/$code-date.csv"
					}
				}
			}
			
			} else {
			"  > L'API de GBIF est inaccessible"
		}
	} # fin GBIF
}  -ThrottleLimit 4 # fin parallelisation TELECHARGEMENT


### FUSION DES CHANGEMENTS

$bdd_codes | ForEach-Object -Parallel {
	$bdd_nom = $_.BDD_NOM
	$bdd_min = $_.BDD_MIN
	$icon = $_.ICON
	$bdd_url = $_.BDD_URL
	
	$files = Get-ChildItem "./BDD/$bdd_nom/" -Filter *.csv
	foreach ($f in $files){
		$fichier = $f.Name
		$espece = $f.Name -replace ".csv"
		
		"Fusion des changements $espece dans $bdd_nom"
		
		$fichier_bdd = Import-Csv "./BDD/$bdd_nom/$fichier"
		$fichier_temp = Import-Csv "./temp/$bdd_nom/$fichier"
		
		$nouveau_fichier = @()
		
		# Suppression des observations supprimées
		foreach ($ligne in $fichier_bdd) {
			$ligneExistante = $fichier_temp | Where-Object { $_.ID -eq $ligne.ID }
			
			if ($ligneExistante) {
				$nouveau_fichier += $ligne
			}
		}
		
		# Vérification des ajouts et mises à jour des observations
		foreach ($ligne in $fichier_temp) {
			$ligneExistante = $nouveau_fichier | Where-Object { $_.ID -eq $ligne.ID }
			
			if ($ligneExistante) {
				$index = $nouveau_fichier.IndexOf($ligneExistante)
				# Si la ligne existe et que les coordonnées existent alors on vérifie la date
				if ($ligne.Latitude -eq $ligneExistante.Latitude -and $ligne.Longitude -eq $ligneExistante.Longitude) {
					if ($ligne.Date -eq $ligneExistante.Date) {} else { $nouveau_fichier[$index].Date = $ligne.Date	}
					# Si les coordonnées ne correspondent pas on copie toute la ligne
					} else {
					$nouveau_fichier[$index] = $ligne
				}
				# Si l'ID n'existe pas on ajoute la ligne
				} else {
				$nouveau_fichier += $ligne
			}
		}
		
		$nouveau_fichier | Export-Csv "./BDD/$bdd_nom/$fichier" -NoTypeInformation -UseQuotes Never
		
	}
}   -ThrottleLimit 4 # fin parallelisation TELECHARGEMENT

#Remove-Item -LiteralPath "temp" -Force -Recurse


### SAUVEGARDE GIT
git config user.name 'github-actions[bot]'
git config user.email 'github-actions[bot]@users.noreply.github.com'
git add .
git commit -m "[Bot] Téléchargement des données"
git push origin main -f
