const config = {
  _id: "rs0",
  members: [{ _id: 0, host: "mongo:27017" }]
};

function waitForPrimary(maxRetries = 20, delayMs = 500) {
  for (let attempt = 0; attempt < maxRetries; attempt += 1) {
    try {
      const status = rs.status();
      if (status.ok === 1 && status.myState === 1) {
        return status;
      }
    } catch (statusError) {
      if (!(statusError.codeName === "NotYetInitialized" || /not yet initialized/i.test(statusError.message ?? ""))) {
        throw statusError;
      }
    }

    sleep(delayMs);
  }

  throw new Error("Replica set failed to reach PRIMARY state in time.");
}

try {
  const status = rs.status();
  if (status.ok === 1) {
    print("Replica set already configured:", status.set);
  }
} catch (error) {
  if (error.codeName === "NotYetInitialized" || /not yet initialized/i.test(error.message ?? "")) {
    print("Initializing single-node replica set");
    rs.initiate(config);

    try {
      const readyStatus = waitForPrimary();
      print("Replica set initiated:", readyStatus.set);
    } catch (waitError) {
      print("Replica set still starting:", waitError.message);
    }

    try {
      db.getSiblingDB("admin").runCommand({
        setDefaultRWConcern: { defaultWriteConcern: { w: "majority" }, defaultReadConcern: { level: "local" } }
      });
    } catch (rwError) {
      print("setDefaultRWConcern failed (will continue):", rwError.message);
    }
  } else {
    throw error;
  }
}
