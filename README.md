# GameScraper
Scrape chess games from live broadcast sites to PGN files
1. Download the PowerShell module GameScraper.psm1 to your computer
2. This PowerShell module uses Selenium.WebDriver 3.14.0 for .Net Framework 4.5, which you can downlaod from - https://www.nuget.org/packages/Selenium.WebDriver/3.14.0
3. This PowerShell module uses Selenium.WebDriver.Support 3.14.0 for .Net Framework 4.5, which you can downlaod from - https://www.nuget.org/api/v2/package/Selenium.Support/3.14.0"
4. Save the Nuget package, and rename the downloaded file with extension .zip so you can open it with File Explorer on Windows
5. Copy lib\net45\WebDriver.dll to the same folder of the GameScraper.psm1 file
6. Copy lib\net45\WebDriver.Support.dll to the same folder of the GameScraper.psm1 file
7. You need to have Google Chrome instealled on your compuer
8. Check the version of your Chrome version (e.g.  97.0.4692.71) and download the mathing version of chromedriver.exe from https://chromedriver.chromium.org/downloads
9. Save chromedriver.exe to the same folder of your Chrome - e.g. C:\Program Files\Google\Chrome\Application
10. Open PowerShell in the folder of GameScraper.psm1
11. You many need to unlock these files are they are downloaded from Interet with commands -
    Unblock-File .\GameScraper.psm1
    Unblock-File .\WebDriver.dll
    Unblock-File .\WebDriver.Support.dll
12. Import Module -
    ipmo GameScraper.psm1
13. You need to find the tournametn URL from chessbomb.com, followchess.com or livechesscloud.com
E.g. https://www.chessbomb.com/arena/2022-tata-steel-chess-tournament-masters
14. Run command - Download-LiveChessGames
15. It will prompt for touranment link and then download all finished games to a PGN.
Enjoy!
   
