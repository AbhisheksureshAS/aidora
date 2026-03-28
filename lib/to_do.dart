import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {

  final List<Map<String, dynamic>> taskList = [];

  TextEditingController name = TextEditingController();
  TextEditingController desc = TextEditingController();
  TextEditingController time = TextEditingController();

  @override
  void initState() {
    super.initState();

    FirebaseFirestore.instance.collection("Task").get().then((snapshot) {
      for (var doc in snapshot.docs) {
        taskList.add(doc.data());
      }
      setState(() {});  
    });
  }

  void addTask() {
    FirebaseFirestore.instance.collection("Task").add({
      "name": name.text,
      "desc": desc.text,
      "time": DateTime.now().toString(),
    });

    setState(() {
      taskList.add({
        "name": name.text,
        "desc": desc.text,
        "time": DateTime.now().toString(),
      });
    });

    name.clear();
    desc.clear();
    time.clear();
  }

  void openDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("New Task"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: InputDecoration(hintText: "Task")),
            TextField(controller: desc, decoration: InputDecoration(hintText: "Description")),
            TextField(controller: time, decoration: InputDecoration(hintText: "Time")),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              addTask();
              Navigator.pop(context);
            },
            child: Text("Add"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Todo")),
      floatingActionButton: FloatingActionButton(
        onPressed: openDialog,
        child: Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: taskList.length,
        itemBuilder: (context, i) {
          return ListTile(
            title: Text(taskList[i]["name"] ?? ""),
            subtitle: Text(
              "${taskList[i]["desc"] ?? ""}   (${taskList[i]["time"] ?? ""})",
            ),
          );
        },
      ),
    );
  }
}