# Invitation-only Betas
## Extension Attributes

- [Jamf-Protect-Pilot-Plist.xml](Jamf-Protect-Pilot-Plist.xml)
- [Microsoft-Defender-Pilot-Plist.xml](Microsoft-Defender-Pilot-Plist.xml)

---

### Configuration

1. Download the desired Extension Attribute [from the list above](#extension-attributes) 
1. [Upload](https://docs.jamf.com/10.29.0/jamf-pro/administrator-guide/Computer_Extension_Attributes.html#src-81928610_id-.ComputerExtensionAttributesv10.27.0-UploadingaTemplateforaComputerExtensionAttribute) the downloaded Computer Extension Attribute
1. Modify `filepath` to match the **Reverse Domain Name Notation** for your organization (i.e., `org.churchofjesuschrist`)
1. Click **Save**

(Use [Property List Writer](https://github.com/dan-snelson/Invitation-only-Betas/tree/main/Scripts#property-list-writer) to write the desired values.)