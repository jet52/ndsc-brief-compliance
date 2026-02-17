document.addEventListener('DOMContentLoaded', function() {
  const form = document.getElementById('upload-form');
  const fileInput = document.getElementById('pdf');
  const fileName = document.getElementById('file-name');
  const dropZone = document.getElementById('drop-zone');
  const submitBtn = document.getElementById('submit-btn');
  const spinner = document.getElementById('spinner');

  // Show selected file name
  fileInput.addEventListener('change', function() {
    if (this.files.length > 0) {
      fileName.textContent = this.files[0].name;
    } else {
      fileName.textContent = '';
    }
  });

  // Drag and drop styling
  dropZone.addEventListener('dragover', function(e) {
    e.preventDefault();
    this.classList.add('dragover');
  });

  dropZone.addEventListener('dragleave', function() {
    this.classList.remove('dragover');
  });

  dropZone.addEventListener('drop', function(e) {
    this.classList.remove('dragover');
  });

  // Show spinner on submit
  form.addEventListener('submit', function() {
    submitBtn.disabled = true;
    submitBtn.style.display = 'none';
    spinner.style.display = 'block';
  });
});
