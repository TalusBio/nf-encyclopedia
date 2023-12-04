//
// This file holds useful functions
// It is based on nf-core's NfcoreTemplate
//


class TalusTemplate {
    //
    // Construct and send completion email
    //
    // Returns
    // -------
    // str
    //     The HTML email body.
    public static email(workflow, params) {
        // Set the email subject:
        def subject = "[$workflow.manifest.name] SUCCESS: ${workflow.runName}"
        if (!workflow.success) {
            subject = "[$workflow.manifest.name] FAILED ${workflow.runName}"
        }

        // Used in ../assets/email_template.html
        def email_fields = [:]
        email_fields['started']      = workflow.start
        email_fields['dateComplete'] = workflow.complete
        email_fields['runName']      = workflow.runName
        email_fields['uuid']         = workflow.sessionId
        email_fields['success']      = workflow.success
        email_fields['duration']     = workflow.duration
        email_fields['exitStatus']   = workflow.exitStatus
        email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
        email_fields['errorReport']  = (workflow.errorReport ?: 'None')
        email_fields['commandLine']  = workflow.commandLine
        email_fields['projectDir']   = workflow.projectDir

        // Complete the email template:
        def engine = new groovy.text.GStringTemplateEngine()
        def html_path = "${workflow.projectDir}/assets/email_template.html"
        def html_file = new File(html_path)
        def html_template = engine.createTemplate(html_file).make(email_fields)
        def email_html = html_template.toString()
        return [subject, email_html]
    }

    //
    // Construct and send a notification to a web server as JSON
    // e.g. Microsoft Teams and Slack
    //
    public static void IM_notification(workflow, params, projectDir) {
        def hook_url = params.hook_url
        def misc_fields = [:]
        misc_fields['start']                                = workflow.start
        misc_fields['complete']                             = workflow.complete
        misc_fields['scriptfile']                           = workflow.scriptFile
        misc_fields['scriptid']                             = workflow.scriptId
        if (workflow.repository) misc_fields['repository']  = workflow.repository
        if (workflow.commitId)   misc_fields['commitid']    = workflow.commitId
        if (workflow.revision)   misc_fields['revision']    = workflow.revision
        misc_fields['nxf_version']                          = workflow.nextflow.version
        misc_fields['nxf_build']                            = workflow.nextflow.build
        misc_fields['nxf_timestamp']                        = workflow.nextflow.timestamp

        def summary = [:]
        def msg_fields = [:]
        msg_fields['runName']      = workflow.runName
        msg_fields['success']      = workflow.success
        msg_fields['dateComplete'] = workflow.complete
        msg_fields['duration']     = workflow.duration
        msg_fields['exitStatus']   = workflow.exitStatus
        msg_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
        msg_fields['errorReport']  = (workflow.errorReport ?: 'None')
        msg_fields['commandLine']  = workflow.commandLine.replaceFirst(/ +--hook_url +[^ ]+/, "")
        msg_fields['projectDir']   = workflow.projectDir
        msg_fields['summary']      = summary << misc_fields

        // Render the JSON template
        def engine       = new groovy.text.GStringTemplateEngine()
        // Different JSON depending on the service provider
        // Defaults to "Adaptive Cards" (https://adaptivecards.io), except Slack which has its own format
        def json_path     = hook_url.contains("hooks.slack.com") ? "slackreport.json" : "adaptivecard.json"
        def hf            = new File("$projectDir/assets/${json_path}")
        def json_template = engine.createTemplate(hf).make(msg_fields)
        def json_message  = json_template.toString()

        // POST
        def post = new URL(hook_url).openConnection();
        post.setRequestMethod("POST")
        post.setDoOutput(true)
        post.setRequestProperty("Content-Type", "application/json")
        post.getOutputStream().write(json_message.getBytes("UTF-8"));
        def postRC = post.getResponseCode();
    }
}
