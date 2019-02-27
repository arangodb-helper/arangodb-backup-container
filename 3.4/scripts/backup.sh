#!/bin/sh
cat > /tmp/backup-js$$.js <<'EOF'
const fs = require("fs");
const executeExternalAndWait = require("internal").executeExternalAndWait;
const exit = require("internal").exit;
const env = require("internal").env;

let defaults = {
  ARANGO_ENDPOINT: "tcp://127.0.0.1:8529",
  ARANGO_USERNAME: "root",
  ARANGO_PASSWD: "",
  ARANGO_CLEAN_DUMP_DIRECTORY: "no",
  ARANGO_DUMP_DIRECTORY: "/backup/dump",
  ARANGO_DUMP_THREADS: 2,
  ARANGO_LOGFILE: "-",
};

function getEnv(variable) {
  if (env.hasOwnProperty(variable)) {
    if (defaults[variable] === null && env[variable] === '') {
      abort("empty value specified for mandatory environment variable '" + variable + "'");
    }
    return env[variable];
  }
  if (defaults.hasOwnProperty(variable)) {
    if (defaults[variable] === null) {
      abort("no value specified for mandatory environment variable '" + variable + "'");
    }
    return defaults[variable];
  }
  return "";
}

function booleanize(variable) {
  const value = getEnv(variable);
  switch (value.toLowerCase()) {
    case 'true':
    case '1':
    case 'y':
    case 'yes':
      return true;

    case 'false':
    case '0':
    case 'n':
    case 'no':
      return false;
  }

  abort("no or invalid value specified for environment variable '" + variable + "'. expecting a boolean value");
}

function log(msg = "") {
  let file = getEnv("ARANGO_LOGFILE");
  if (file === "-") {
    // hack for stdout
    print(msg);
  } else {
    fs.append(file, msg + "\n");
  }
}

function abort(msg, code = 1) {
  log("Fatal error: " + msg);
  exit(code);
}
    
function foregroundTty() {
  let file = getEnv("ARANGO_LOGFILE");
  return file === '-';
}

function cleanDirectory(directory) {
  if (!booleanize("ARANGO_CLEAN_DUMP_DIRECTORY")) {
    abort("will not overwrite a non-empty output directory. please start with environment variable ARANGO_CLEAN_DUMP_DIRECTORY=true to do so");
  }

  log("cleaning directory '" + directory + "'...");
  let files = fs.list(directory).filter(function(file) { return file !== '' && file !== '..' && file !== '.'; });
  files.forEach(function(file) {
    let name = fs.join(directory, file);
    if (fs.isFile(name)) {
      fs.remove(name);
    } else {
      fs.removeDirectoryRecursive(name, true);
    }
  });
  log("cleaned directory '" + directory + "'");
}

function getServerVersion(endpoint, username, password) {
  log("fetching server version from endpoint " + endpoint + " using username '" + username + "'");

  let tmp = fs.getTempFile();
    
  let args = [
    "--server.endpoint", endpoint,
    "--server.username", username,
    "--server.password", password,
    "--server.database", "_system",
    "--javascript.execute-string", "require('fs').write('" + tmp + "', JSON.stringify(db._version()));",
    "--log.file", getEnv("ARANGO_LOGFILE"),
    "--log.foreground-tty", foregroundTty(),
    "--quiet",
  ];
       
  let result = executeExternalAndWait("arangosh", args);
  if (result.exit !== 0) {
    abort("unable to invoke arangosh: exit code: " + result.exit);
  }

  try {
    return JSON.parse(fs.read(tmp));
  } catch (err) {
    abort("unable to retrieve server version. error: " + err);
  }
} 
  
function getNumericServerVersion(endpoint, username, password) {
  const version = getServerVersion(endpoint, username, password);
  let parts = version.split(/\./g);
  return parseInt(parts[0] || 0) * 10000 + parseInt(parts[1] || 0) * 100 + parseInt(parts[2] || 0);
}
  
function getDatabases(endpoint, username, password) {
  log("fetching databases from endpoint " + endpoint + " using username '" + username + "'");

  let tmp = fs.getTempFile();
    
  let args = [
    "--server.endpoint", endpoint,
    "--server.username", username,
    "--server.password", password,
    "--server.database", "_system",
    "--javascript.execute-string", "require('fs').write('" + tmp + "', JSON.stringify(db._databases()));",
    "--log.file", getEnv("ARANGO_LOGFILE"),
    "--log.foreground-tty", foregroundTty(),
    "--quiet",
  ];
       
  let result = executeExternalAndWait("arangosh", args);
  if (result.exit !== 0) {
    abort("unable to invoke arangosh: exit code: " + result.exit);
  }

  try {
    return JSON.parse(fs.read(tmp));
  } catch (err) {
    abort("unable to retrieve list of databases. error: " + err);
  }
} 

function validateToolArguments(tool, args) {
  for (let i = 0; i < args.length; ++i) {
    if (!args[i].match(/^--[a-z0-9]+(\.[a-z0-9\-]+)*/)) {
      // invalid option pattern
      abort("invalid argument for tool " + tool + ": " + args[i]);
    }
  }
}

function runBackup() {
  validateToolArguments("arangodump", ARGUMENTS);
  let outputDirectory = getEnv("ARANGO_DUMP_DIRECTORY").trim();
    
  if (fs.isDirectory(outputDirectory)) {
    log("dump output directory " + outputDirectory + " already exists");
  } else {
    fs.makeDirectoryRecursive(outputDirectory);
  }

  let files = fs.listTree(outputDirectory).filter(function(file) { return file !== ''; });
  if (files.length === 0) {
    log("dump output directory " + outputDirectory + " is empty");
  } else {
    log("dump output directory " + outputDirectory + " is not empty");
    cleanDirectory(outputDirectory);
  }
        
  let endpoint = getEnv("ARANGO_ENDPOINT");
  let username = getEnv("ARANGO_USERNAME");
  let password = getEnv("ARANGO_PASSWD");
  
  const numericVersion = getNumericServerVersion(endpoint, username, password);

  const databases = getDatabases(endpoint, username, password);

  log("dumping databases...");
  databases.forEach(function(database) {
    const directory = fs.join(outputDirectory, database);
    log("dumping database " + database + " into directory '" + directory + "'...");

    let args = [
      "--server.endpoint", endpoint,
      "--server.username", username,
      "--server.password", password,
      "--server.database", database,
      "--output-directory", directory,
      "--include-system-collections", "true",
      "--log.file", getEnv("ARANGO_LOGFILE"),
      "--log.foreground-tty", foregroundTty(),
    ];
      
    if (numericVersion >= 30400) {
      // threads only supported from 3.4 onwards
      args.push("--threads");
      args.push(getEnv("ARANGO_DUMP_THREADS"));
    }

    // append extra args
    for (let i = 0; i < ARGUMENTS.length; ++i) {
      args.push(ARGUMENTS[i]);
    }
       
    // finally invoke arangodump
    let result = executeExternalAndWait("arangodump", args);
    if (result.exit !== 0) {
      abort("unable to invoke arangodump: exit code: " + result.exit);
    }
  });
}

function runRestore() {
  validateToolArguments("arangorestore", ARGUMENTS);
  let inputDirectory = getEnv("ARANGO_DUMP_DIRECTORY").trim();
    
  if (!fs.isDirectory(inputDirectory)) {
    abort("restore input directory " + inputDirectory + " does not exist");
  }
  
  let databases = [];
  let files = fs.list(inputDirectory).filter(function(file) { return file !== '' && file !== '..' && file !== '.' && fs.isDirectory(fs.join(inputDirectory, file)); });
  files.forEach(function(file) {
    let name = fs.join(inputDirectory, file);
    if (fs.isDirectory(name)) {
      databases.push(file);
    }
  });

  log("the following databases will be restored: " + databases.join(", "));

  let endpoint = getEnv("ARANGO_ENDPOINT");
  let username = getEnv("ARANGO_USERNAME");
  let password = getEnv("ARANGO_PASSWD");
  
  const numericVersion = getNumericServerVersion(endpoint, username, password);

  log("restoring databases...");
  databases.forEach(function(database) {
    const directory = fs.join(inputDirectory, database);
    log("restoring database " + database + " from directory '" + directory + "'...");

    let args = [
      "--server.endpoint", endpoint,
      "--server.username", username,
      "--server.password", password,
      "--server.database", database,
      "--input-directory", directory,
      "--create-database", "true",
      "--include-system-collections", "true",
      "--log.file", getEnv("ARANGO_LOGFILE"),
      "--log.foreground-tty", foregroundTty(),
    ];
      
    if (numericVersion >= 30400) {
      // threads only supported from 3.4 onwards
      args.push("--threads");
      args.push(getEnv("ARANGO_DUMP_THREADS"));
    }

    // append extra args
    for (let i = 0; i < ARGUMENTS.length; ++i) {
      args.push(ARGUMENTS[i]);
    }
       
    // finally invoke arangorestore
    let result = executeExternalAndWait("arangorestore", args);
    if (result.exit !== 0) {
      abort("unable to invoke arangorestore: exit code: " + result.exit);
    }
  });
}

function selfCheck() {
  const tools = ["arangosh", "arangodump", "arangorestore"];

  tools.forEach(function(tool) {
    let result = executeExternalAndWait(tool, ['--check-configuration']);
    if (result.exit !== 0) {
      abort("unable to invoke tool " + tool + ": exit code: " + result.exit + ". maybe it is not available in the path?");
    }
  });
}
    
function printHelp() {
  let self = "backup.sh"; //fs.normalize(global.__filename).split(/\//).pop();

  log();
  log("usage: " + self + " (dump|restore) <passthrough options>");
  log();
  log("the following environment variables will be recognized:");
  Object.keys(defaults).forEach(function(variable) {
    log(" - " + variable);
  });
  log();
}

function main() {
  selfCheck();

  if (ARGUMENTS.length < 1) {
    // too few arguments specified
    printHelp();
    exit(1);
  }

  // available commands
  const handlers = {
    backup: runBackup,
    dump: runBackup,
    restore: runRestore,
    help: printHelp,
  };

  let command = ARGUMENTS[0];
  if (!handlers.hasOwnProperty(command)) {
    abort("invalid command '" + command + "'. available commands are: " + Object.keys(handlers).join(", "));
  }
  // pop the command off the argument list
  ARGUMENTS.shift();
  handlers[command]();
}

main();
EOF

if test "ARANGO_HOSTS" != ""; then
  echo $ARANGO_HOSTS >> /etc/hosts
  echo "Using /etc/hosts"
  cat /etc/hosts
  echo "Using /etc/resolv.conf"
  cat /etc/resolv.conf
fi

if test "$1" = "sh"; then
  shift
  /bin/sh "$@"
else
  arangosh --server.endpoint none --javascript.execute /tmp/backup-js$$.js "$@"
fi
