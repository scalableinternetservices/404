# CS291A Project4-5

## LLM (Amazon Bedrock) Setup

- Local development:
  - Copy AWS creds from jump box:
    ```zsh
    scp project2backend@ec2.cs291.com:~/.aws/credentials ~/.aws/cs291_credentials
    ```
  - Do NOT commit these credentials.
  - `docker-compose.yml` mounts host creds and sets `AWS_SHARED_CREDENTIALS_FILE=/app/.aws/cs291_credentials`.
- Rails app changes:
  - Gem: add `aws-sdk-bedrockruntime`.
  - Model: `app/models/current.rb` with `attribute :might_be_locust_request`.
  - Controller: `ApplicationController` includes cookies and detects Locust via user-agent.
  - Service: `app/services/bedrock_client.rb` wraps Bedrock Converse API and fakes responses unless `ALLOW_BEDROCK_CALL=true`.
- Elastic Beanstalk:
  - Use an instance profile with Bedrock access and enable calls via:
    ```zsh
    eb create <env_name> \
      --envvars "ALLOW_BEDROCK_CALL=true" \
      --profile eb-with-bedrock-ec2-profile
    ```

## Universal LLM API Endpoint

- Route: `POST /llm`
- Body JSON:
  ```json
  {"system_prompt":"You are a helpful assistant.","user_prompt":"Explain eventual consistency."}
  ```
- Response example:
  ```json
  {
    "ok": true,
    "message": "Eventual consistency means...",
    "model_id": "anthropic.claude-3-5-haiku-20241022-v1:0",
    "fake": false,
    "usage": {"input_tokens": 42, "output_tokens": 128, "total_tokens": 170},
    "latency_ms": 873
  }
  ```
- Returns `fake: true` if Bedrock calls are disabled (no creds / `ALLOW_BEDROCK_CALL` not true or Locust load test).
- Set `BEDROCK_MODEL_ID` to override default model.

Curl test (real or fake depending on env):
```zsh
curl -X POST http://localhost:3000/llm \
  -H 'Content-Type: application/json' \
  -d '{"system_prompt":"You are a helpful assistant.","user_prompt":"Say hi."}'
```
### How to deploy on AWS

```zsh
ssh -i ~/Downloads/xinghan-404.pem 404@ec2.cs291.com
```

```zsh
eb create prod-llm \
  --platform "64bit Amazon Linux 2023 v4.7.1 running Ruby 3.4" \
  --region us-west-2 \
  --cname prod-llm-$(whoami) \
  --keyname $(whoami) \
  --instance_type m7g.medium \
  --instance_profile eb-with-bedrock-ec2-profile \
  --envvars "ALLOW_BEDROCK_CALL=true,RAILS_ENV=production,RAILS_SERVE_STATIC_FILES=true,BEDROCK_MODEL_ID=anthropic.claude-3-5-haiku-20241022-v1:0" \
  --scale 1
```
Prereqs (run once)
```zsh
cd ~/TEAMNAME/help_desk_backend
eb init --keyname $(whoami) --platform "64bit Amazon Linux 2023 v4.7.1 running Ruby 3.4" --region us-west-2 TEAMNAME
```

Single Instance (m7g.medium app, db.m5.large)
```zsh
eb create single --envvars SECRET_KEY_BASE=BADSECRET,RAILS_ENV=production,RAILS_SERVE_STATIC_FILES=true \
  -db.engine mysql -db.i db.m5.large -db.user u \
  -i m7g.medium --single
eb status single
```

Vertical Scaling (m7g.large app, db.m5.large)
```zsh
eb create vertical --envvars SECRET_KEY_BASE=BADSECRET,RAILS_ENV=production,RAILS_SERVE_STATIC_FILES=true \
  -db.engine mysql -db.i db.m5.large -db.user u \
  -i m7g.large --single
eb status vertical
```

Horizontal Scaling 1 (4× m7g.medium app, db.m5.large)
```zsh
eb create horiz1 --envvars SECRET_KEY_BASE=BADSECRET,RAILS_ENV=production,RAILS_SERVE_STATIC_FILES=true \
  -db.engine mysql -db.i db.m5.large -db.user u \
  -i m7g.medium
eb scale 4 --environment horiz1
eb status horiz1
```

Horizontal Scaling 2 + Larger DB (4× m7g.medium app, db.m5.xlarge)
```zsh
eb create horiz2 --envvars SECRET_KEY_BASE=BADSECRET,RAILS_ENV=production,RAILS_SERVE_STATIC_FILES=true \
  -db.engine mysql -db.i db.m5.xlarge -db.user u \
  -i m7g.medium
eb scale 4 --environment horiz2
eb status horiz2
```

Notes
- Use the  CNAME from `eb status` as your `--host` in Locust.


