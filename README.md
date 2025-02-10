# trip advice agent firebase

## Local Development

```bash
$ export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)"/.service-account-file.json"

$ firebase emulators:start
```

# Deploy

```bash
$ firebase deploy --only functions

$ curl -XGET "${HOST}/v2/projects/ai-agent-hackathon-fc785/locations/us-central1/addmessage?text=uppercaseme"
```