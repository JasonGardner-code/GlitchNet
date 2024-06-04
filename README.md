# GlitchNet

![glitchNet_logo](https://github.com/JasonGardner-code/GlitchNet/assets/51766718/d8c8a560-c5db-423c-8b8d-7347d329eb82)

How to use:

1. Download the repo.

2. Chmod +x glitchnet.sh

3. sudo ./glitchnet.sh 

4. In burp suite setup the proxying rules (see the README)

5. On the mobile device search for the Wi-Fi SSID "GlitchNet". The first password will be Test@123. Please change this when you run it.

6. Connect and browse the internet.

7. Monitor intercepted traffic in Burp Suite.

![glitchnet](https://github.com/JasonGardner-code/GlitchNet/assets/51766718/3793d97d-1dfa-46d6-bfbb-c68c737357f3)



https://github.com/JasonGardner-code/GlitchNet/assets/51766718/0596d38f-4a67-4bea-82f3-1675fcd6ada8



Multipane View:
![multiplePaneView](https://github.com/JasonGardner-code/GlitchNet/assets/51766718/1640129a-0a93-45ba-9ea4-505e44f53d9f)


PoC for MiTM attack:
Here for a simple proof of concept using BurpSuite's match and replace rules on the response body it is possible to inject an alert.

Without the injection:

![glitchnetload1](https://github.com/JasonGardner-code/GlitchNet/assets/51766718/420c973c-ed6c-42eb-ada5-213c10c92c5c)

With the injection:

![glitchnetload2](https://github.com/JasonGardner-code/GlitchNet/assets/51766718/12c85e2f-f4e8-4a75-8af1-993ab12d8f63)


Show your support:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-%23FFDD00.svg?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/iamtherealjason)



