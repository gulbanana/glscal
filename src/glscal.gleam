import argv

import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor

type Message {
  SetPartner(partner: Subject(Message))
  Dance
  Sing(number: Int)
}

type State {
  State(value: Int, partner: Option(Subject(Message)))
}

fn loop(message: Message, state: State) {
  case message {
    // used during init to break cycles - after this, we assume partner is set
    SetPartner(partner) -> {
      actor.continue(State(..state, partner: Some(partner)))
    }

    // begin by sending our partner our starting state
    Dance -> {
      let assert Some(next) = state.partner
      actor.send(next, Sing(state.value))
      actor.continue(state)
    }

    // pass on the values we receive endlessly
    Sing(number) -> {
      // if we've got the 0, print our own initial value
      case number == 0 {
        True ->
          state.value
          |> int.to_string
          |> io.println
        False -> Nil
      }

      // pass it on
      process.sleep(1000)
      let assert Some(next) = state.partner
      actor.send(next, Sing(number))
      actor.continue(state)
    }
  }
}

// create an actor and then recurse to create N-1 more, chaining their partners
fn build_rec(first: Subject(Message), acc: Int) {
  case acc {
    0 -> []
    x -> {
      case build_rec(first, x - 1) {
        [] -> {
          let assert Ok(last) = actor.start(State(0, Some(first)), loop)
          [last]
        }
        [head, ..tail] -> {
          let assert Ok(next) = actor.start(State(x, Some(head)), loop)
          [next, head, ..tail]
        }
      }
    }
  }
}

// create N actors in a loop
fn build(n: Int) {
  let assert Ok(first) = actor.start(State(n, None), loop)
  let assert [last, ..rest] = build_rec(first, n - 1)
  actor.send(first, SetPartner(last))
  [last, ..rest]
}

pub fn main() {
  case argv.load().arguments {
    [count] -> {
      let assert Ok(actors) = int.parse(count)
      build(actors)
      |> list.each(actor.send(_, Dance))

      process.sleep_forever()
    }
    _ -> io.println("usage: ./glscal <count>")
  }
}
