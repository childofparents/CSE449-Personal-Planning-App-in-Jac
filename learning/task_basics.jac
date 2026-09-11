# Step 1: model a task and change its state in memory.
# Run from A1/learning: jac run
# This example does not save tasks between runs.

node Task {
    has title: str;
    has done: bool = False;
}

with entry:__main__ {
    task = Task(title="Learn the basics of Jac");
    print(f"Task: {task.title}");
    print(f"Completed: {task.done}");

    task.done = True;
    print(f"Completed after update: {task.done}");
}
