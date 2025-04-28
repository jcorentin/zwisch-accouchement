import answer.{type Answer}
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type Accouchement {
  Accouchement(
    user: String,
    poste_chef: String,
    moment: String,
    instrument: String,
    autonomie: String,
    raison: Option(String),
  )
}

pub fn decode() -> decode.Decoder(Accouchement) {
  use user <- decode.field("user", decode.string)
  use poste_chef <- decode.field("poste_chef", decode.string)
  use moment <- decode.field("moment", decode.string)
  use instrument <- decode.field("instrument", decode.string)
  use autonomie <- decode.field("autonomie", decode.string)
  use raison <- decode.field("autonomie_raison", decode.string)
  decode.success(Accouchement(
    user:,
    poste_chef:,
    moment:,
    instrument:,
    autonomie:,
    raison: string.to_option(raison),
  ))
}

pub fn encode(acc: Accouchement) -> Json {
  json.object([
    #("user", json.string(acc.user)),
    #("poste_chef", json.string(acc.poste_chef)),
    #("moment", json.string(acc.moment)),
    #("instrument", json.string(acc.instrument)),
    #("autonomie", json.string(acc.autonomie)),
    #("autonomie_raison", acc.raison |> option.unwrap("") |> json.string),
  ])
}

pub type Question {
  PosteChef
  Moment
  Instrument
  Autonomie
  Raison(Autonomie)
}

pub type Autonomie {
  Observe
  AideActive
  AideMineure
}

pub fn questions_to_accouchement(
  questions: Dict(Question, Answer),
  user_id: String,
) -> Result(Accouchement, Nil) {
  let questions =
    answer.validate_multiple(questions)
    |> result.replace_error(Nil)
  use validated_questions <- result.try(questions)
  use poste_chef <- result.try(dict.get(validated_questions, PosteChef))
  use moment <- result.try(dict.get(validated_questions, Moment))
  use instrument <- result.try(dict.get(validated_questions, Instrument))
  use autonomie <- result.try(dict.get(validated_questions, Autonomie))
  use raison <- result.try(case autonomie {
    "observe" ->
      validated_questions |> dict.get(Raison(Observe)) |> result.map(Some)
    "aide_active" ->
      validated_questions
      |> dict.get(Raison(AideActive))
      |> result.map(Some)
    "aide_mineure" ->
      validated_questions
      |> dict.get(Raison(AideMineure))
      |> result.map(Some)
    "sans_aide" -> Ok(None)
    _ -> Error(Nil)
  })
  Ok(Accouchement(
    user: user_id,
    poste_chef:,
    moment:,
    instrument:,
    autonomie:,
    raison:,
  ))
}

pub fn new_questions() -> Dict(Question, Answer) {
  [
    #(PosteChef, answer.NoAnswer),
    #(Moment, answer.NoAnswer),
    #(Instrument, answer.NoAnswer),
    #(Autonomie, answer.NoAnswer),
  ]
  |> dict.from_list()
}

pub fn update_questions(questions, update) {
  let #(question, answer) = update
  let questions = dict.insert(questions, question, answer)
  let upsert_raison = fn(raison_question) {
    dict.upsert(questions, raison_question, fn(existing_answer) {
      case existing_answer {
        Some(answer) -> answer
        None -> answer.NoAnswer
      }
    })
  }
  case dict.get(questions, Autonomie) {
    Ok(answer.Proposed("observe")) ->
      upsert_raison(Raison(Observe))
      |> dict.drop([Raison(AideActive), Raison(AideMineure)])
    Ok(answer.Proposed("aide_active")) ->
      upsert_raison(Raison(AideActive))
      |> dict.drop([Raison(Observe), Raison(AideMineure)])
    Ok(answer.Proposed("aide_mineure")) ->
      upsert_raison(Raison(AideMineure))
      |> dict.drop([Raison(Observe), Raison(AideActive)])
    _ ->
      dict.drop(questions, [
        Raison(Observe),
        Raison(AideActive),
        Raison(AideMineure),
      ])
  }
}
