function Get-DGTTournamentID($tournamentUrl)
{
   $tournamentUrl = $tournamentUrl.Trim();
   if($tournamentUrl -match "#")
   {
        $tournamentId = $tournamentUrl.Split("#")[-1]
   }
   else
   {
        $tournamentId = $tournamentUrl.Split("/")[-1]
        $tournamentId = $tournamentId.Replace("#","")
   }
   return $tournamentId
}

function Get-DGTRoundJSONUrl ($tournamentId, $round, $baseUri="http://1.pool.livechesscloud.com/get/")
{
   $roundJSONUrl = $baseUri+$tournamentId+"/round-"+$round+"/index.json"
   return $roundJSONUrl
}

function Get-DGTGameJSONUrl ($tournamentId, $round, $gameNum, $baseUri="http://1.pool.livechesscloud.com/get/")
{
   #https://1.pool.livechesscloud.com/get/5c4f0155-8001-4b12-956d-68595b385b34/round-5/game-1.json
   $gameJSONUrl = $baseUri+$tournamentId+"/round-"+$round+"/game-"+$gameNum+".json"
   return $gameJSONUrl
}


function Get-DGTTournamentInfo($tournamentId, $baseUri="https://1.pool.livechesscloud.com/get/")
{
    $tournamentJSONUrl = $baseUri+$tournamentId+"/tournament.json"
    try
    {
        $response = Invoke-WebRequest -Uri "$tournamentJSONUrl"
        $jsonObj = ConvertFrom-Json $([String]::new($response.Content))
        if ($jsonObj -ne $null) 
        {
            return $jsonObj
        }
        else
        {
            return $null
        }
    }
    catch
    {
        return $null
    }
}

function Get-DGTRoundInfo($tournamentId, $round, $baseUri="https://1.pool.livechesscloud.com/get/")
{
    #https://1.pool.livechesscloud.com/get/5c4f0155-8001-4b12-956d-68595b385b34/round-5/index.json
    $roundJSONUrl = Get-DGTRoundJSONUrl -tournamentId $tournamentId -round $round

    try
    {
        $response = Invoke-WebRequest -Uri "$roundJSONUrl"
        $jsonObj = ConvertFrom-Json $([String]::new($response.Content))
        if ($jsonObj -ne $null) 
        {
            return $jsonObj
        }
        else
        {
            return $null
        }
    }
    catch
    {
        return $null
    }
}

function Get-DGTGameInfo($tournamentId, $round, $gameNum, $baseUri="https://1.pool.livechesscloud.com/get/")
{
    #https://1.pool.livechesscloud.com/get/5c4f0155-8001-4b12-956d-68595b385b34/round-5/game-1.json
    $gameJSONUrl = Get-DGTGameJSONUrl -tournamentId $tournamentId -round $round -gameNum $gameNum
    Write-Verbose $gameJSONUrl

    try
    {
        $response = Invoke-WebRequest -Uri "$gameJSONUrl"
        $jsonObj = ConvertFrom-Json $([String]::new($response.Content))
        if ($jsonObj -ne $null) 
        {
            return $jsonObj
        }
        else
        {
            return $null
        }
    }
    catch
    {
        return $null
    }
}

function Get-DGTMoveString ( [string[]] $moves, [string] $result)
{
    if($moves -eq $null)
    {
        return $result
    }

    $moveString =''
    
    for($i = 1; $i*2 -le $moves.Count; $i++)
    {
        $moveString = $moveString + $i.ToString()+". "+$moves[2*($i-1)].Split(" ")[0]+" "+$moves[2*($i-1)+1].Split(" ")[0]+" "
    }
    
    if($($moves.Count) %2 -eq 1) #odd moves, last move is not yet in
    {
        $moveString = $moveString + ($([Math]::floor($moves.Count/2))+1).ToString()+". "+$moves[-1].Split(" ")[0]+" "
    }
    
    
    $moveString = $moveString + $result


    return $moveString

}


function Download-FromDGTLive ()
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string] $tournamentUrl,
        [string] $tournamentLocation,
        [string] $PGNFileName
        )

    if([string]::IsNullOrEmpty($tournamentUrl))
    {
        $tournamentUrl = Read-Host "Please provide the live chess cloud link - (e.g.http://view.livechesscloud.com/#5c4f0155-8001-4b12-956d-68595b385b34) "
    }
    
    
    $tournamentId = Get-DGTTournamentID -tournamentUrl $tournamentUrl
        
    $tournamentInfo = Get-DGTTournamentInfo -tournamentId $tournamentId 

    if($tournamentInfo -eq $null)
    {
        Write-Host "Not tournament found with the provided link ", $tournamentUrl
        return $null
    } 

    if($tournamentInfo.location -eq $null -and [string]::IsNullOrEmpty($tournamentLocation))
    {
        $tournamentLocation = Read-Host "What's the location of the event (e.g. Seattle, USA) : "
    }


    if([string]::IsNullOrEmpty($PGNFileName))
    {
        $PGNFileName = "DGTLive_"+$tournamentInfo.name + $(Get-Date -format "_yyyy.MM.dd.HH.mm.ss")+".PGN"
        $PGNFileName = $PGNFileName.Replace("\","_")
        $PGNFileName = $PGNFileName.Replace("/","_")
        Write-Host "No file name is provided. Use the default file name " $PGNFileName
    }
    

    if($tournamentInfo -ne $null)
    {
        Write-Host -ForegroundColor Green "Downloading games for event : ",$tournamentInfo.name
        for($r = 1; $r -le $tournamentInfo.rounds.Count; $r++ )
        {
            if($tournamentInfo.rounds[$r-1].count -eq 0 )
            {
                Write-Host "Round ",$r, " not-started"
            }
            elseif ($tournamentInfo.rounds[$r-1].live -ne 0)
            {
                Write-Host "Round ",$r, " ongoing"
            }
            else
            {
                Write-Host "Round ",$r, " finished"
                $roundInfo = Get-DGTRoundInfo -tournamentId $tournamentId -round $r
                if($roundInfo -ne $null)
                {
                   for($g =1; $g -le $roundInfo.pairings.Count; $g++ )
                   {
                        $gameInfo = Get-DGTGameInfo -tournamentId $tournamentId -round $r -gameNum $g

                        if($gameInfo.result -ne "NOTPLAYED")
                        {
                            $movesString = Get-DGTMoveString -moves $($gameInfo.Moves) -result $roundInfo.pairings[$g-1].result
                            if($tournamentInfo.name -ne $null)
                            {
                                $event = '[Event "'+$tournamentInfo.name.Trim()+'"]'
                            }
                            else
                            {
                                $event = '[Event "?"]'
                            }


                            if($tournamentInfo.location -ne $null)
                            {
                                $site = '[Site "'+$tournamentInfo.location+'"]'
                            }
                            else
                            {
                                $site = '[Site "$tournamentLocation"]'
                            }
                        
                        
                            $date = '[Date "'+$((Get-Date 01.01.1970).AddSeconds($gameInfo.firstMove/1000).ToString("yyyy.MM.dd"))+'"]'
                            $round = '[Round "'+$r+'.'+$g+'"]'
                            $white = '[White "'+$roundInfo.pairings[$g-1].white.lname+", "+$roundInfo.pairings[$g-1].white.fname+'"]'
                            if($roundInfo.pairings[$g-1].white.fideid -ne $null)
                            {
                                $whiteFideId = '[WhiteFideId "'+$roundInfo.pairings[$g-1].white.fideid+'"]'
                            }
                            else
                            {
                                $whiteFideId = $null
                            }
                        
                            $black = '[Black "'+$roundInfo.pairings[$g-1].black.lname+", "+$roundInfo.pairings[$g-1].black.fname+'"]'
                        
                            if($roundInfo.pairings[$g-1].black.fideid -ne $null)
                            {
                                $blackFideId = '[BlackFideId "'+$roundInfo.pairings[$g-1].black.fideid+'"]'
                            }
                            else
                            {
                                $blackFideId = $null
                            }

                            $result = '[Result "'+$roundInfo.pairings[$g-1].result+'"]'
                            $plyCount = '[PlyCount "'+$gameInfo.moves.Count+'"]'
                    
                            $event | Out-File $PGNFileName -Append -Encoding ascii
                            $site  | Out-File $PGNFileName -Append -Encoding ascii
                            $date  | Out-File $PGNFileName -Append -Encoding ascii
                            $round | Out-File $PGNFileName -Append -Encoding ascii
                            $white | Out-File $PGNFileName -Append -Encoding ascii
                            $whiteFideId  | Out-File $PGNFileName -Append -Encoding ascii
                            $black  | Out-File $PGNFileName -Append -Encoding ascii
                            $blackFideId | Out-File $PGNFileName -Append -Encoding ascii
                            $result  | Out-File $PGNFileName -Append -Encoding ascii
                            $plyCount  | Out-File $PGNFileName -Append -Encoding ascii
                            [System.Environment]::NewLine | Out-File $PGNFileName -Append -Encoding ascii
                            $movesString | Out-File $PGNFileName -Append -Encoding ascii
                            [System.Environment]::NewLine | Out-File $PGNFileName -Append -Encoding ascii
                            Write-Host "Event : ",$event,"]", "Round ",$r," Game ",$g," : ",$white," ",$roundInfo.pairings[$g-1].result,$black
                        }
                        else
                        {
                            Write-Host -ForegroundColor Red "Game not played :", "Event : ",$event,"]", "Round ",$r," Game ",$g," : ",$white," ",$roundInfo.pairings[$g-1].result,$black
                        }

                   }

                }
            }

        }
    }

    Write-Host -ForegroundColor Green "Games saved to file : ", $PGNFileName
    
    return $PGNFileName
}

function Download-FromFollowChess ()
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string] $tournamentUrl,
        [string] $tournamentLocation,
        [string] $PGNFileName,
        [bool] $headless=$true
        )
    
    $workingPath = $PSScriptRoot
   
    # This is required for the ChromeDriver to work.
    if (($env:Path -split ';') -notcontains $workingPath) {
        $env:Path += ";$workingPath"
    }

    # Import Selenium to PowerShell using the Import-Module cmdlet.
    $webdriverPath = $workingPath+"\WebDriver.dll"
    if($(Test-Path $webdriverPath -PathType Leaf) -ne $true)
    {
        Write-Host -ForegroundColor Red "WebDriver doesn't exist in the same folder as the module. Please download 3.1.4 version from https://www.nuget.org/api/v2/package/Selenium.WebDriver/3.14.0"
        return $null
    }

    $webdriverSupportPath = $workingPath+"\WebDriver.Support.dll"
    if($(Test-Path $webdriverSupportPath -PathType Leaf) -ne $true)
    {
        Write-Host -ForegroundColor Red "WebDriver Suport DLL doesn't exist in the same folder as the module. Please download 3.1.4 version from https://www.nuget.org/api/v2/package/Selenium.Support/3.14.0"
        return $null
    }
    


    Unblock-File "$($workingPath)\WebDriver.dll" #unblock it first since its downloaded from Internet
    Unblock-File "$($workingPath)\WebDriver.Support.dll" #unblock it first since its downloaded from Internet

    Add-Type -Path "$($workingPath)\WebDriver.dll"
    Add-Type -Path "$($workingPath)\WebDriver.Support.dll"

    if([string]::IsNullOrEmpty($tournamentUrl))
    {
        $tournamentUrl = Read-Host "Input the link to the Follow Chess Event (e.g. https://live.followchess.com/#!new-york-winter-invitational-gm-a-2022) "
    }
     
    if([string]::IsNullOrEmpty($tournamentLocation))
    {    
        $tournamentLocation = Read-Host "Where is the event "
    }

    if($headless)
    {
        $ChromeOptions = New-Object OpenQA.Selenium.Chrome.ChromeOptions
        $ChromeOptions.addArguments('headless')
        $ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($ChromeOptions)
    }
    else
    {
        $ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver
    }

    $ChromeDriver.Navigate().GoToURL($tournamentUrl)
    #sleep 5

    $seleniumWait = New-Object -TypeName OpenQA.Selenium.Support.UI.WebDriverWait($ChromeDriver, (New-TimeSpan -Seconds 10))
    $seleniumWait.Until([OpenQA.Selenium.Support.UI.ExpectedConditions]::ElementIsVisible([OpenQA.Selenium.By]::TagName("canvas"))) | Out-Null
    

    $tournamentHeader = $ChromeDriver.FindElementByClassName("trnheader")
    $Event = $tournamentHeader.Text.Split("(")[0].Trim()
    $Round = $tournamentHeader.Text.Split("(")[1].Split(")")[0].Split(" ")[1]

    if([string]::IsNullOrEmpty($PGNFileName))
    {
        $PGNFileName = "FollowChess_"+ $($Event+$Round+$(Get-Date -Format "yyyyMMdd_HHmmss")+".pgn").Replace(" ","_")
    }

    $games=$ChromeDriver.FindElementsByTagName("canvas")
    $totalGames = $games.Count
    for ($i=0; $i -lt $totalGames; $i++)
    {
    
        $games[$i].click()
        $seleniumWait.Until([OpenQA.Selenium.Support.UI.ExpectedConditions]::ElementIsVisible([OpenQA.Selenium.By]::ClassName("maingame"))) | Out-Null
        #sleep 5
        $players = $ChromeDriver.FindElementsByClassName("PKERRHC-c-g")
        $ratings = $ChromeDriver.FindElementsByClassName("PKERRHC-c-k")
    
    
        try 
                                                                                                    {
        $result = $ChromeDriver.FindElementByClassName("result").Text
        if($result -eq "½-½") 
        {
            $result = "1/2-1/2"
        }

        Write-Host "Game finished : ",$players[0].Text," ",$result," ",$players[1].Text

        $moves = $ChromeDriver.FindElementByClassName("maingame").Text
        $moves = $moves.Replace("½-½","1/2-1/2")

        $plyCount = $moves.Split(" ").Count -1
        $plyCount =  [math]::Round($plyCount *2 /3)
        '[Event '+'"'+$event+'"]'| Out-File $PGNFileName -Append -Encoding ascii
        '[Site '+'"'+$tournamentLocation+'"]' | Out-File $PGNFileName -Append -Encoding ascii
        '[Date '+'"'+$(Get-Date -Format 'yyyy.MM.dd')+'"]' | Out-File $PGNFileName -Append -Encoding ascii
        '[Round '+'"'+$Round+'.'+$($i+1)+'"]' | Out-File $PGNFileName -Append -Encoding ascii
        '[White '+'"'+$players[0].Text+'"]' | Out-File $PGNFileName -Append -Encoding ascii
        '[Black '+'"'+$players[1].Text+'"]' | Out-File $PGNFileName -Append -Encoding ascii
        '[Result '+'"'+$result+ '"]' | Out-File $PGNFileName -Append -Encoding ascii
        '[WhiteElo '+'"'+$ratings[0].text+'"]' | Out-File $PGNFileName -Append -Encoding ascii
        '[BlackElo '+'"'+$ratings[1].text+'"]' | Out-File $PGNFileName -Append -Encoding ascii
        '[PlyCount '+'"'+$plyCount+'"]' | Out-File $PGNFileName -Append -Encoding ascii
        [System.Environment]::NewLine | Out-File $PGNFileName -Append -Encoding ascii
        $moves | Out-File $PGNFileName -Append -Encoding ascii
        [System.Environment]::NewLine | Out-File $PGNFileName -Append -Encoding ascii
    }
        catch
        {
            Write-Host -ForegroundColor Red "Game still playing : ",$players[0].Text," ","*"," ",$players[1].Text
        }
   
        $ChromeDriver.Navigate().GoToURL($tournamentUrl)
        #sleep 5
        $seleniumWait.Until([OpenQA.Selenium.Support.UI.ExpectedConditions]::ElementIsVisible([OpenQA.Selenium.By]::TagName("canvas"))) | Out-Null
        $games=$ChromeDriver.FindElementsByTagName("canvas")
    }
    Write-Host -ForegroundColor Green "Games saved to file : ", $PGNFileName
    return $PGNFileName
}

function Download-FromChessBomb ()
{   
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string] $tournamentUrl,
        [string] $tournamentLocation,
        [string] $PGNFileName,
        [bool] $headless=$true
        )

    $workingPath = $PSScriptRoot
   
    # This is required for the ChromeDriver to work.
    if (($env:Path -split ';') -notcontains $workingPath) {
        $env:Path += ";$workingPath"
    }

    # Import Selenium to PowerShell using the Import-Module cmdlet.
    $webdriverPath = $workingPath+"\WebDriver.dll"
    if($(Test-Path $webdriverPath -PathType Leaf) -ne $true)
    {
        Write-Host -ForegroundColor Red "WebDriver doesn't exist in the same folder as the module. Please download 3.1.4 version from https://www.nuget.org/api/v2/package/Selenium.WebDriver/3.14.0"
        return $null
    }

    $webdriverSupportPath = $workingPath+"\WebDriver.Support.dll"
    if($(Test-Path $webdriverSupportPath -PathType Leaf) -ne $true)
    {
        Write-Host -ForegroundColor Red "WebDriver Suport DLL doesn't exist in the same folder as the module. Please download 3.1.4 version from https://www.nuget.org/api/v2/package/Selenium.Support/3.14.0"
        return $null
    }
    
    Unblock-File "$($workingPath)\WebDriver.dll" #unblock it first since its downloaded from Internet
    Unblock-File "$($workingPath)\WebDriver.Support.dll" #unblock it first since its downloaded from Internet

    Add-Type -Path "$($workingPath)\WebDriver.dll"
    Add-Type -Path "$($workingPath)\WebDriver.Support.dll"

    if([string]::IsNullOrEmpty($tournamentUrl))
    {
        $tournamentUrl = Read-Host "Input the link to the Follow Chess Event (e.g. https://live.followchess.com/#!new-york-winter-invitational-gm-a-2022) "
    }
     
    if([string]::IsNullOrEmpty($tournamentLocation))
    {    
        $tournamentLocation = Read-Host "Where is the event "
    }

    if($headless)
    {
        $ChromeOptions = New-Object OpenQA.Selenium.Chrome.ChromeOptions
        $ChromeOptions.addArguments('headless')
        $ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($ChromeOptions)
    }
    else
    {
        $ChromeDriver = New-Object OpenQA.Selenium.Chrome.ChromeDriver
    }

    $ChromeDriver.Navigate().GoToURL($tournamentUrl)
 
    $seleniumWait = New-Object -TypeName OpenQA.Selenium.Support.UI.WebDriverWait($ChromeDriver, (New-TimeSpan -Seconds 10)) #max wait for 10 seconds
        
    try{
        $seleniumWait.Until([OpenQA.Selenium.Support.UI.ExpectedConditions]::ElementIsVisible([OpenQA.Selenium.By]::XPath("//*[contains(text(), 'Got it!')]"))) | Out-Null
        $cookieButton=$ChromeDriver.FindElementsByXPath("//*[contains(text(), 'Got it!')]")
        $cookieButton.Click()
    }
    catch 
    {
        $cookieButton=$null
    }

    $eventName = $ChromeDriver.FindElementByXpath("/html/body/div[3]/div[3]/div[3]/div[1]/div[2]/div[2]/div/p[1]/a").Text
    

    if([string]::IsNullOrEmpty($PGNFileName))
    {
        $PGNFileName = "ChessBomb_"+ $($eventName+$(Get-Date -Format "yyyyMMdd_HHmmss")+".pgn").Replace(" ","_")
    }
    
    $tables = $ChromeDriver.FindElementsByTagName("tbody")
    $gameTable = $tables[-1] #last table is for chess games
    $roundRows = $gameTable.FindElementsByTagName("tr")

    #expand each round so game result data will be loaded
    foreach ($r in $roundRows)
    {
        $tds=$r.FindElementsByTagName("td")
        if($tds.count -eq 1)
        {
            $span=$tds[0].FindElementByTagName("span")
            if($span.GetAttribute("class") -match "right")
            {
                Write-Verbose "Click $($tds[0].Text)"
                $r.Click()
            }
            else
            {
                Write-Verbose "Opened - skip $($tds[0].Text)"
            }
        }
        else
        {
            Write-Verbose "row is not round header"
        }
    }
    
    #get all table rows after its fully expanded
    $roundRows = $gameTable.FindElementsByTagName("tr")
    $gameIndex =1;
    $games = @()
    foreach ($r in $roundRows)
    {
        try 
        {
            $tds=$r.FindElementsByTagName("td")
            if($tds.count -eq 1)
            {
                $roundText = $tds[0].Text
                $round  =[int] $tds[0].Text
                $gameIndex =1;
                Write-verbose "round $round"
            }
            else
            {
                Write-Host "Game ",$round,".",$gameIndex,$tds[1].Text,$tds[3].Text,$tds[2].Text
                $game = [PSCustomObject]@{
                    Event= $eventName
                    Site =$tournamentLocation
                    Date = Get-Date -Format "yyyy.MM.dd"
                    Round = $round.ToString()+"."+$gameIndex.ToString()
                    White = $tds[1].text
                    Result = $tds[3].text
                    Black = $tds[2].text
                    GameLink = $($tournamentUrl+"/"+$roundText+"-"+$($tds[1].text -Replace ‘[^a-zA-Z]’,'_')+"-"+$($tds[2].text -Replace ‘[^a-zA-Z]’,'_')).Replace("__","_")
                    Moves = ""
                    PlyCount = 0
                }
                if($game.Result -eq "½-½")
                {
                    $game.Result = "1/2-1/2"
                }
                $games+=$game
                $gameIndex = $gameIndex+1;
            }
        }
        catch
        {
            Write-Verbose "row is not round header"
        }

    }

    $games| ft

    foreach ($game in $games)
    {
        Write-Host "Downloading game ",$game.Round,":",$game.White," ",$game.Result," ",$game.Black

        if($game.Result -match "\*")
        {
            Write-Host -ForegroundColor Yellow "Game is not finished. Skipped."
        }
        else
        {
            $ChromeDriver.Navigate().GoToURL($game.GameLink)
            try
            {
                $seleniumWait.Until([OpenQA.Selenium.Support.UI.ExpectedConditions]::ElementIsVisible([OpenQA.Selenium.By]::XPath("/html/body/div[3]/div[3]/div[3]/div[2]/div/div[2]/div/div[2]"))) | Out-Null
                $movesDiv=$ChromeDriver.FindElementsByXPath("/html/body/div[3]/div[3]/div[3]/div[2]/div/div[2]/div/div[2]")
                $game.Moves = $movesDiv.Text
                $game.Moves = $game.Moves.Replace("½-½","1/2-1/2")
                $plyCount = $movesDiv.Text.Split(" ").Count -1
                $plyCount =  [math]::Round($plyCount *2 /3)
                $game.PlyCount = $plyCount

                '[Event '+'"'+$game.Event+'"]'| Out-File $PGNFileName -Append -Encoding ascii
                '[Site '+'"'+$game.Site+'"]' | Out-File $PGNFileName -Append -Encoding ascii
                '[Date '+'"'+$game.Date+'"]' | Out-File $PGNFileName -Append -Encoding ascii
                '[Round '+'"'+$game.Round+'"]' | Out-File $PGNFileName -Append -Encoding ascii
                '[White '+'"'+$game.White+'"]' | Out-File $PGNFileName -Append -Encoding ascii
                '[Black '+'"'+$game.Black+'"]' | Out-File $PGNFileName -Append -Encoding ascii
                '[Result '+'"'+$game.Result+ '"]' | Out-File $PGNFileName -Append -Encoding ascii
                '[PlyCount '+'"'+$game.PlyCount+'"]' | Out-File $PGNFileName -Append -Encoding ascii
                [System.Environment]::NewLine | Out-File $PGNFileName -Append -Encoding ascii
                $game.Moves | Out-File $PGNFileName -Append -Encoding ascii
                [System.Environment]::NewLine | Out-File $PGNFileName -Append -Encoding ascii
                Write-Host -ForegroundColor green "Saved to $PGNFileName"
            }
            catch 
            {
                $cookieButton=$null
                Write-Host -ForegroundColor red "Download Failed"
            }
        }
    }

    Write-Host -ForegroundColor Green "Games saved to file : ", $PGNFileName
    return $PGNFileName
}

function Download-LiveChessGames ()
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string] $tournamentUrl,
        [string] $tournamentLocation,
        [string] $PGNFileName,
        [bool] $headless=$true
        )

    if([string]::IsNullOrEmpty($tournamentUrl))
    {
        $tournamentUrl = Read-Host "What's the tournament? [e.g.http://view.livechesscloud.com/#5c4f0155-8001-4b12-956d-68595b385b34 or https://live.followchess.com/#!tata-steel-masters-2022] "
    }
    if($tournamentUrl -match "view.livechesscloud.com")
    {
        Download-FromDGTLive -tournamentUrl $tournamentUrl -tournamentLocation $tournamentLocation -PGNFileName $PGNFileName
    }
    elseif ($tournamentUrl -match "live.followchess.com")
    {
        Download-FromFollowChess -tournamentUrl $tournamentUrl -tournamentLocation $tournamentLocation -PGNFileName $PGNFileName -headless $headless
    }
    elseif ($tournamentUrl -match "chessbomb.com")
    {
        Download-FromChessBomb -tournamentUrl $tournamentUrl -tournamentLocation $tournamentLocation -PGNFileName $PGNFileName -headless $headless
    }
    else
    {
        Write-Host -ForegroundColor Red "Unsupported tournament link provided."
    }
}

Export-ModuleMember -Function Download-LiveChessGames

