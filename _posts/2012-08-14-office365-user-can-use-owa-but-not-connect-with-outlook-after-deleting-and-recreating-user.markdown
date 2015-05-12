---
layout: post
title: Office 365 user can use OWA but not connect with Outlook after deleting and
  recreating user.
date: '2012-08-14 16:30:34'
---

Problem is that soft deleted user in AD recycle bin is conflicting with newly created user.  
  
Solution:  
  
* Download and install new 365 PoSH tools from http://onlinehelp.microsoft.com/Office365-enterprises/ff652560.aspx  
* Connect to posh and log in.  
  
&gt; $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell/ -Credential $Cred -Authentication  
  
Basic -AllowRedirection  
  
(prompt for admin credentials)  
  
&gt; Import-PSSession $Session  
&gt; Connect-MsolService  
  
&gt; Remove-MsolUser -RemoveFromRecycleBin -UserprincipalName *useremail@domain.com*  
  
* User will be deleted from recycled bin after about 30 seconds.  
* Rename new user to old user in MS Online admin panel.  
* User can now send and receive email in outlook as normal.