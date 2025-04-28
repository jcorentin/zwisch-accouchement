import answer.{type Answer}
import gleam/dict.{type Dict}
import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type User {
  User(id: String, name: String, sexe: Option(String), semestre: Option(String))
}

pub fn decode() -> Decoder(User) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use semestre <- decode.field("semestre", decode.string)
  use sexe <- decode.field("sexe", decode.string)
  decode.success(User(
    id:,
    name: name,
    semestre: string.to_option(semestre),
    sexe: string.to_option(sexe),
  ))
}

pub fn encode(user: User) -> Json {
  [
    #("id", user.id),
    #("name", user.name),
    #("sexe", option.unwrap(user.sexe, "")),
    #("semestre", option.unwrap(user.semestre, "")),
  ]
  |> list.map(fn(item) {
    let #(key, value) = item
    #(key, json.string(value))
  })
  |> json.object
}

pub type Question {
  Sexe
  Semestre
}

pub fn new_questions(user: User) {
  let questions = case user.sexe {
    Some(_sexe) -> []
    None -> [#(Sexe, answer.NoAnswer)]
  }
  case user.semestre {
    Some(_semestre) -> questions
    None -> [#(Semestre, answer.NoAnswer), ..questions]
  }
  |> dict.from_list()
}

pub fn update_user(user: User, update: #(Question, Answer)) {
  let #(question, answer) = update
  let answer = answer |> answer.to_string |> string.to_option
  case question {
    Sexe -> User(..user, sexe: answer)
    Semestre -> User(..user, semestre: answer)
  }
}

pub fn update_questions(
  questions: Dict(Question, Answer),
  update: #(Question, Answer),
) {
  let #(question, answer) = update
  dict.insert(questions, question, answer)
}
