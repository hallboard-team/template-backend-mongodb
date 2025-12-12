const config = {
  _id: "rs0",
  members: [{ _id: 0, host: "mongo:27017" }]
};

try {
  const status = rs.status();
  if (status.ok === 1) {
    print("Replica set already configured:", status.set);
  }
} catch (error) {
  if (error.codeName === "NotYetInitialized" || /not yet initialized/i.test(error.message ?? "")) {
    print("Initializing single-node replica set");
    rs.initiate(config);
    rs.status();

    db.getSiblingDB("admin").runCommand({
      setDefaultRWConcern: { defaultWriteConcern: { w: "majority" }, defaultReadConcern: { level: "local" } }
    });
  } else {
    throw error;
  }
}
