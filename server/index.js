const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const http = require("http");
const Document = require("./models/document");
const authRouter = require("./routes/auth");
const documentRouter = require("./routes/document");


const port = process.env.PORT || 3001;



const app = express();
var server = http.createServer(app);
var io = require("socket.io")(server);

app.use(cors());
app.use(express.json()); // ✅ middleware first
app.use(authRouter);     // ✅ then routes
app.use(documentRouter);


const DB = "mongodb://<your username>:<your id>@ac-a3psufu-shard-00-00.joevxhb.mongodb.net:27017,ac-a3psufu-shard-00-01.joevxhb.mongodb.net:27017,ac-a3psufu-shard-00-02.joevxhb.mongodb.net:27017/?ssl=true&replicaSet=atlas-5la61m-shard-0&authSource=admin"

mongoose
    .connect(DB)
    .then(() => {
        console.log("Connection successful!");
    })
    .catch((err) => {
        console.log(err, authRouter);

    });

io.on("connection", (socket) => {
    socket.on("join", (documentId) => {
        socket.join(documentId);
        console.log("joined room " + documentId);
    });

    socket.on("typing", (data) => {
        socket.broadcast.to(data.room).emit("changes", data);
    });

    socket.on("save", (data) => {
        saveData(data);
    });
});

const saveData = async (data) => {
  try {
    // Use findByIdAndUpdate to bypass version errors
    await Document.findByIdAndUpdate(
      data.room,
      { content: data.delta },
       { returnDocument: 'after', useFindAndModify: false } // ✅ updated option
    );
    // Optionally, broadcast latest content back to clients
    io.to(data.room).emit("saved", data.delta);
} catch (err) {
    console.error("Error saving document:", err);
  }
};
server.listen(port, "0.0.0.0", () => {
    console.log(`connected at port ${port}`);
});
