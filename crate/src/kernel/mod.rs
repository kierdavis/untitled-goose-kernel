fn show_demo_message() {
  static HELLO: &[u8] = b"Hello, world!";
  let vga_buffer = 0xb8000 as *mut u8;
  for (i, &byte) in HELLO.iter().enumerate() {
    unsafe {
      *vga_buffer.offset(i as isize * 2) = byte;
      *vga_buffer.offset(i as isize * 2 + 1) = 0xb;
    }
  }
}

fn my_actor_constructor() {
  show_demo_message()
}

#[derive(Debug)]
struct TooManyActorsError;

#[derive(Debug)]
struct ActorID(usize);

#[derive(Debug)]
struct ActorSpec; // we don't support different kinds of actor yet - they all do the same thing.

#[derive(Debug)]
struct Actor;
impl Actor {
  fn from_spec(_spec: ActorSpec) -> Self {
    Actor
  }
  fn execute_constructor(&self) {
    my_actor_constructor()
  }
}

const MAX_ACTORS: usize = 16;
#[derive(Debug)]
struct ActorCollection([Option<Actor>; MAX_ACTORS]);
impl ActorCollection {
  fn new() -> Self {
    ActorCollection([None; MAX_ACTORS])
  }
  fn add(&mut self, actor: Actor) -> Result<(ActorID, &Actor), TooManyActorsError> {
    for (index, slot) in self.0.iter_mut().enumerate() {
      match *slot {
        Some(_) => (),
        None => {
          return Ok((ActorID(index), slot.get_or_insert(actor)));
        },
      }
    }
    Err(TooManyActorsError)
  }
}

#[derive(Debug)]
struct Kernel {
  actors: ActorCollection,
}
impl Kernel {
  fn new() -> Self {
    Kernel {
      actors: ActorCollection::new(),
    }
  }
  fn spawn(&mut self, actor_spec: ActorSpec) -> Result<ActorID, TooManyActorsError> {
    let actor = Actor::from_spec(actor_spec);
    let (actor_id, actor_ref) = self.actors.add(actor)?;
    actor_ref.execute_constructor();
    Ok(actor_id)
  }
}

pub fn main() -> ! {
  let mut kernel = Kernel::new();
  kernel.spawn(ActorSpec).unwrap();
  loop {}
}
