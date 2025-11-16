<script>
export default {
  name: "CreateDoc",
};
</script>
<template>
  <form
    id="addDoc"
    method="post"
    enctype="multipart/form-data"
    action="//localhost:8000/createdoc"
    target="_blank"
  >
    <label for="inp-id">ID:</label><br />
    <input type="text" name="doc_id" id="inp-id" required /><br />
    <label for="inp-title">Наименование:</label><br />
    <input type="text" name="title" id="inp-title" required /><br />
    <label for="inp-mcb">МКБ-10:</label><br />
    <input type="text" name="mcb" id="inp-mcb" /><br />
    <label for="inp-acat">Возрастная группа:</label><br />
    <input type="text" name="age_category" id="inp-acat" /><br />
    <label for="inp-dev">Разработчик:</label><br />
    <input type="text" name="developer" id="inp-dev" /><br />
    <label for="inp-file">Документ:</label><br />
    <input type="file" name="file" id="inp-file" required accept=".pdf" /><br />
    <input type="submit" value="Добавить" />
  </form>
</template>
