package com.sentinelops.tasktracker;

import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/tasks")
@RequiredArgsConstructor
public class TaskController {

    private final TaskRepository repository;

    @PostMapping
    public ResponseEntity<Task> create(@RequestBody @NotBlank String title) {
        Task task = new Task();
        task.setTitle(title);
        return ResponseEntity.status(HttpStatus.CREATED).body(repository.save(task));
    }

    @GetMapping
    public List<Task> list() {
        return repository.findAll();
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        if (!repository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        repository.deleteById(id);
        return ResponseEntity.noContent().build();
    }
}
