Story = require('../models/story.js')
https  = require('https')

describe Story, ->

  describe "setTypeFromSubject", ->
    it "defaults to 'feature'", ->
      story = new Story
        subject: 'A Feature'
      story.setTypeFromSubject()
      expect(story.get('type')).toEqual('feature');

    it "sets 'bug' if inferred", ->
      story = new Story
        subject: 'This is a Bug'
      story.setTypeFromSubject()
      expect(story.get('type')).toEqual('bug');

  describe "setLabelsFromSubject", ->
    it "extracts individual labels in [foo] [bar] format", ->
      story = new Story
        subject: 'A Feature [foo] [bar]'
      story.setLabelsFromSubject()
      expect(story.get('labels')).toEqual(['foo', 'bar', 'new'])

    it "extracts individual labels in [foo, bar] format", ->
      story = new Story
        subject: 'A Feature [foo, bar]'
      story.setLabelsFromSubject()
      expect(story.get('labels')).toEqual(['foo', 'bar', 'new'])

    it "extracts individual labels in [foo, bar] [baz] format", ->
      story = new Story
        subject: 'A Feature [foo, bar] [baz]'
      story.setLabelsFromSubject()
      expect(story.get('labels')).toEqual(['foo', 'bar', 'baz', 'new'])

    it "does not change labels if already set", ->
      story = new Story
        labels: ['foo']
        subject: 'A Feature [bar]'
      story.setLabelsFromSubject()
      expect(story.get('labels')).toEqual(['foo'])

    it "removes specified labels from the subject", ->
      story = new Story
        subject: 'A Feature [foo]'
      story.setLabelsFromSubject()
      expect(story.get('subject')).toEqual('A Feature')

  describe "setNameFromSubject", ->
    it "sets name without prefix RE:", ->
      story = new Story
        subject: 'RE: A feature'
      story.setNameFromSubject()
      expect(story.get('name')).toEqual('A feature')

      story = new Story
        subject: 'Re: A feature'
      story.setNameFromSubject()
      expect(story.get('name')).toEqual('A feature')

    it "sets name without prefix FW:", ->
      story = new Story
        subject: 'FW: A feature'
      story.setNameFromSubject()
      expect(story.get('name')).toEqual('A feature')

      story = new Story
        subject: 'Fw: A feature'
      story.setNameFromSubject()
      expect(story.get('name')).toEqual('A feature')   

    it "sets name without prefix FWD:", ->
      story = new Story
        subject: 'FWD: A feature'
      story.setNameFromSubject()
      expect(story.get('name')).toEqual('A feature')

      story = new Story
        subject: 'Fwd: A feature'
      story.setNameFromSubject()
      expect(story.get('name')).toEqual('A feature')

    it "sets name without prefix 'Fwd: FW:'", ->
      story = new Story
        subject: 'Fwd: FW: A feature'
      story.setNameFromSubject()
      expect(story.get('name')).toEqual('A feature')

      story = new Story
        subject: 'Fwd: A feature'
      story.setNameFromSubject()
      expect(story.get('name')).toEqual('A feature')

    it "sets proper name when subject begins with prefix 'Re'", ->
      story = new Story
        subject: 'Reaction to this post'
      story.setNameFromSubject()
      expect(story.get('name')).toEqual('Reaction to this post')

    it "trims name string from white space at the front and end", ->
      story = new Story
        subject: ' A feature '
      story.setNameFromSubject()
      expect(story.get('name')).toEqual('A feature')  

  describe "fromAddress", ->
    it "returns the name without the email address", ->
      story = new Story
        from: 'John Doe <john.doe@foo.com>'
      expect(story.fromAddress()).toEqual 'john.doe@foo.com'

  describe "toAddress", ->
    it "returns the name without the email address", ->
      story = new Story
        to: 'John Doe <john.doe@foo.com>'
      expect(story.toAddress()).toEqual 'john.doe@foo.com'

  describe "ccAddress", ->
    it "returns the name without the email address", ->
      story = new Story
        cc: 'John Doe <john.doe@foo.com>'
      expect(story.ccAddress()).toEqual 'john.doe@foo.com'

      story = new Story
        cc: 'john.doe@foo.com'
      expect(story.ccAddress()).toEqual 'john.doe@foo.com'

  describe "toXml", ->
    story = null
    beforeEach ->
      story = new Story
        projectId: '123'
        token:     'abc'
        fromName:  'John Doe'
        toName:  'John Doe'
        subject:   'Test'
        body:      'test body'

    it "returns the story xml", ->
      xml = story.toXml()
      expect(xml).toEqual(
        '<story><name>Test</name>' +
        '<story_type>feature</story_type>' +
        '<requested_by>John Doe</requested_by>' +
        '<owned_by>John Doe</owned_by>' +
        '<labels>new</labels><description>test body</description></story>'
      )

    it "escapes the name field value", ->
      story = new Story
        subject: 'Foo <Bar>'
      xml = story.toXml()
      expect(xml).toMatch(/<name>Foo &lt;Bar&gt;<\/name>/);

    it "escapes the requested_by field value", ->
      story.set
        fromName: 'John & Jane Doe'
      xml = story.toXml()
      expect(xml).toMatch(/<requested_by>John &amp; Jane Doe<\/requested_by>/);

    it "escapes the description field value", ->
      story.set
        body: 'Foo <Bar>'
      xml = story.toXml()
      expect(xml).toMatch(/<description>Foo &lt;Bar&gt;<\/description>/);

  describe "getUserNameFromXML", ->
    story = null
    xml = '<?xml version="1.0" encoding="UTF-8"?>
           <memberships type="array">
             <membership>
               <id>1</id>
               <person>
                 <email>john@example.com</email>
                 <name>John Smith</name>
                 <initials>JS</initials>
               </person>
               <role>Owner</role>
               <project>
                 <id>123</id>
                 <name>Foo</name>
               </project>
             </membership>
             <membership>
               <id>2</id>
               <person>
                 <email>jane@example.com</email>
                 <name>Jane Williams</name>
                 <initials>JW</initials>
               </person>
               <role>Owner</role>
               <project>
                 <id>123</id>
                 <name>Foo</name>
               </project>
             </membership>
           </memberships>'
    beforeEach ->
      story = new Story()
    
    it "returns the user name based on specified email", ->
      name = story.getUserNameFromXML(xml, 'jane@example.com')
      expect(name).toEqual('Jane Williams')
  
  describe "getProjectsIdsFromXML", ->
    story = null
    xml = '<?xml version="1.0" encoding="UTF-8"?>
           <projects type="array">
             <project>
               <id>123321</id>
               <name>test</name>
               <iteration_length type="integer">2</iteration_length>
               <week_start_day>Monday</week_start_day>
               <point_scale>0,1,2,3</point_scale>
               <velocity_scheme>Average of 4 iterations</velocity_scheme>
               <current_velocity>10</current_velocity>
               <initial_velocity>10</initial_velocity>
               <number_of_done_iterations_to_show>12</number_of_done_iterations_to_show>
               <labels>shields,transporter</labels>
               <allow_attachments>true</allow_attachments>
               <public>false</public>
               <use_https>true</use_https>
               <bugs_and_chores_are_estimatable>false</bugs_and_chores_are_estimatable>
               <commit_mode>false</commit_mode>
               <last_activity_at type="datetime">2010/01/16 17:39:10 CST</last_activity_at>'

    beforeEach ->
      story = new Story()
    
    it "returns array of project names and ids", ->
      ids = story.getProjectsIdsFromXML(xml)
      expect(ids).toEqual({'test': '123321'})

  describe "normalizeString", ->
    it "returns lowercase string without spaces", ->
      story = new Story()
      expect(story.normalizeString('AbcD eFG hiJKLMn')).toEqual('abcdefghijklmn')
      

  describe "save", ->
    story = null
    beforeEach ->
      story = new Story
        token:     'abc'
        from:      'John Doe <john.doe@foo.com>'
        to:        'John Doe <john.doe@foo.com>'
        cc:        'Pivgeon <test@pivgeon.com>'
        subject:   'Test'
        body:      'test body'

    describe "POST", ->
      onSpy = writeSpy = endSpy = null

      beforeEach ->
        onSpy    = jasmine.createSpy('on')
        writeSpy = jasmine.createSpy('write')
        endSpy   = jasmine.createSpy('end')
        spyOn(https, 'request').andReturn({on: onSpy, write: writeSpy, end: endSpy})
        spyOn(story, 'getProjectIdByName').andCallFake (projName, cb) ->
          cb('1212123')
        spyOn(story, 'getUserNamesFromEmails').andCallFake (fromEmail,ccEmail, cb) ->
          cb('John Doe','John Doe')
        story.save()

      it "sends a POST to the PT api", ->
        params = https.request.mostRecentCall.args[0]
        expect(https.request).toHaveBeenCalled()
        params = https.request.mostRecentCall.args[0]
        expect(params.path).toEqual('/services/v3/projects/1212123/stories')
        expect(params.headers['X-TrackerToken']).toEqual('abc')
        expect(onSpy).toHaveBeenCalled()
        expect(onSpy.mostRecentCall.args[0]).toEqual('error')
        expect(writeSpy).toHaveBeenCalledWith(story.toXml())
        expect(endSpy).toHaveBeenCalled()

    it "sends notification to sender when project does not exist", ->
      spyOn(story,'getProjectIdByName').andCallFake (name,cb) ->
        cb(null);
      story.bind 'uncreated', (e) ->        
        expect(e).toMatch(/The project 'test' does not exist/)
      story.bind 'error', (e) ->
        expect(e).toMatch(/The project does not exist/)
      story.save()

  describe "handlePivotalError", ->
    story = null
    beforeEach ->
      story = new Story      

    it "triggers both methods: 'uncreated' and 'error'", ->
      story.bind 'uncreated', (e) ->        
        expect(e).toMatch(/Pivotal Tracker server error/)
      story.bind 'error', (e) ->
        expect(e).toMatch(/Response status: 500/)
      story.handlePivotalError {statusCode: '500'}, ''

    it "triggers method 'uncreated' with proper error message when response status is 5xx", ->      
      story.bind 'uncreated', (err)->
        expect(err).toMatch(/Pivotal Tracker server error/)
      story.handlePivotalError {statusCode: '501'}, ""

    it "triggers method 'uncreated' with proper error message when response status is 422", ->      
      story.bind 'uncreated', (err)->
        expect(err).toMatch(/The provided requested_by user James Kirk is not a valid member of the project./)
      resBody = '<?xml version="1.0" encoding="UTF-8"?>
                 <errors>
                   <error>The provided requested_by user James Kirk is not a valid member of the project.</error>
                 </errors>'

      story.handlePivotalError {statusCode: '422'}, resBody

    it "triggers method 'uncreated' with proper error message when response status is not 422 and 5xx", ->      
      story.bind 'uncreated', (err)->
        expect(err).toEqual('We are sorry, something went wrong and Book Order could not create new story for you.')
      story.handlePivotalError {statusCode: '404'}, ""
      
      
