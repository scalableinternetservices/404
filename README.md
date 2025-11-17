# CS291A Project4-5
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
eb scale 4 horiz1
eb status horiz1
```

Horizontal Scaling 2 + Larger DB (4× m7g.medium app, db.m5.xlarge)
```zsh
eb create horiz2 --envvars SECRET_KEY_BASE=BADSECRET,RAILS_ENV=production,RAILS_SERVE_STATIC_FILES=true \
  -db.engine mysql -db.i db.m5.xlarge -db.user u \
  -i m7g.medium
eb scale 4 horiz2
eb status horiz2
```

Notes
- Use the  CNAME from `eb status` as your `--host` in Locust.

