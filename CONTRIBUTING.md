## Run Locally
Clone the project

```bash
  git clone https://link-to-project
```

Go to the project directory

```bash
  cd my-project
```

Install dependencies

```bash
  gem build rails_webauthn.gemspec
```

Go to your appplication directory where it needs to be installed, and add it to the Gemfile.

```Gemfile
  gem 'rails_webauthn', path: 'path/to/the/gem/directory'
```

Then install the gems for the application
```
  bundle install
```