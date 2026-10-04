
function Show-ExitScreen {
    Clear-Host
    Write-Host 'IDA MAKHDAMLKCH BIEN dir "Delete Ryu power".'
    Write-Host "Adrob tala 3la TikTok w matnssach follow"
    Pause
    Start-Process "https://linktr.ee/Ryu0833"
    exit
}

Clear-Host
Write-Host "rak baghi dir Power plan ta3i ?"
Write-Host " 1 - yes"
Write-Host " 2 - no "
Write-Host "================================"
$choice1 = Read-Host "Select number"

if ($choice1 -eq '2') {
    Show-ExitScreen
}

Clear-Host

powercfg -setactive SCHEME_BALANCED

# Recherche et suppression de l'ancien Ryu Powerplan
$powerPlans = powercfg -list
foreach ($plan in $powerPlans) {
    if ($plan -match "Ryu Powerplan") {
        # Extraction du GUID propre via Regex
        $guid = [regex]::Match($plan, '([a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12})', 'IgnoreCase').Value
        if ($guid) {
            powercfg -delete $guid
            Write-Host "Deleted Ryu Powerplan with GUID: $guid"
        }
    }
}

Clear-Host
Write-Host "Cha3ndkl cpu ?"
Write-Host " 1 - AMD"
Write-Host " 2 - Intel "
Write-Host " 0 - Delete Ryu power"
Write-Host "================================"
$choice2 = Read-Host "Select number"

if ($choice2 -eq '0') {
    Show-ExitScreen
}

if ($choice2 -eq '1') {
    # Configuration du profil AMD
    Clear-Host
    Write-Host "[INFO] Creating new Ryu powerplan..."
    $duplicate = powercfg -duplicatescheme SCHEME_BALANCED
    $guid = [regex]::Match($duplicate, '([a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12})', 'IgnoreCase').Value
    
    if ($guid) {
        Write-Host "Detected GUID = $guid"
        powercfg -changename $guid "Ryu Powerplan" "Ryu custom performance power plan"
        powercfg -setactive $guid
        
        Clear-Host
        powercfg -setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
        powercfg -setacvalueindex SCHEME_CURRENT 48672f38-7a9a-4bb2-8bf8-3d85be19de4e 2bfc24f9-5ea2-4801-8213-3dbae01aa39d 0
        powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 0
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 4b92d758-5a24-4851-a470-815d78aee119 100
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 7b224883-b3cc-4d79-819f-8374152cbe7c 100
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 45bcc044-d885-43e2-8605-ee0ec6e96b59 100
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 0
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 4d2b0152-7d5c-498b-88e2-34345392a2c5 5000
        powercfg -setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 94d3a615-a899-4ac5-ae2b-e4d8f634367f 1
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 93b8b6dc-0698-4d1c-9ee4-0644e900c85d 0
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 100  
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bae08b81-2d5e-4688-ad6a-13243356654b 0
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 619b7505-003b-4e82-b7a6-4dd29c300971 100
    }
}
elseif ($choice2 -eq '2') {
    # Configuration du profil Intel
    Clear-Host
    Write-Host "[INFO] Creating new Ryu powerplan..."
    $duplicate = powercfg -duplicatescheme SCHEME_MIN
    $guid = [regex]::Match($duplicate, '([a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12})', 'IgnoreCase').Value
    
    if ($guid) {
        Write-Host "Detected GUID = $guid"
        powercfg -changename $guid "Ryu Powerplan" "Ryu custom performance power plan"
        powercfg -setactive $guid
        
        Clear-Host
        powercfg -setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
        powercfg -setacvalueindex SCHEME_CURRENT 48672f38-7a9a-4bb2-8bf8-3d85be19de4e 2bfc24f9-5ea2-4801-8213-3dbae01aa39d 0
        powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 0
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 4b92d758-5a24-4851-a470-815d78aee119 100
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 7b224883-b3cc-4d79-819f-8374152cbe7c 100
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 45bcc044-d885-43e2-8605-ee0ec6e96b59 100
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 4d2b0152-7d5c-498b-88e2-34345392a2c5 5000
        powercfg -setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 94d3a615-a899-4ac5-ae2b-e4d8f634367f 1
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 93b8b6dc-0698-4d1c-9ee4-0644e900c85d 5
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 100  
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bae08b81-2d5e-4688-ad6a-13243356654b 5
        powercfg -setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 619b7505-003b-4e82-b7a6-4dd29c300971 100
    }
}

Show-ExitScreen