# ASD-0224-P1-G1-Vaultwarden
ASD SESSION 2024 02, projet 1, installation automatisée vaultwarden


In the hardening file the default SSH connexion Port will be set to 1754 with an variable. That variable can be modified.
Please take note of that, before run the script. To adapt your future connexions and other scripts using SSH. Notify other peoples.
Or set the port in the script to your current Port 
PORT=1754


## Developpement 
### Hardening part
In the hardening scripts, there is a section that can be commented out to facilitate easier development with syntax highlighting in Visual Studio Code.
When you are developing, you can comment out the "REMOTE_COMMANDS" block at the top and at the bottom of the script. This allows you to leverage the full syntax highlighting and code editing features of your IDE.
Do ctrl + f "REMOTE_COMMANDS" to find them