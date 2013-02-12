{ Block, Comment, Literal, Param, Code, Arr, Value, Call } = require "./nodes"


module.exports = (mainNode) ->

  # Finding `define` statement
  # Has to be a direct child of the main node
  defineBlock = null
  
  mainNode.eachChild (node) ->

    if node.constructor.name == "Comment" and /^\s*define/gm.test(node.comment)
      if matches = node.comment.match(/\s*([^\"\n\s\:]+)\s*:\s*([^\"\n\s\:]+)\s*/gm)
        
        defineBlock = 
          sources : []
          targets : []
          node : node
        
        for match in matches
          if pair = match.match(/\s*([^\"\n\s\:]+)\s*:\s*([^\"\n\s\:]+)\s*/m)
            defineBlock.sources.push(pair[1])
            defineBlock.targets.push(pair[2])

  if defineBlock

    # Rewriting the node tree
     
    if mainNode.expressions.indexOf(defineBlock.node) >= 0
      
      mainNode.expressions = (node for node in mainNode.expressions when node != defineBlock.node)

    mainNode = new Block([
      new Call(
        new Value(new Literal("define"))
        [
          new Arr(defineBlock.sources.map( (a) -> new Value(new Literal("\"#{a}\"")) ))
          new Code(
            defineBlock.targets.map( (a) -> new Param(new Literal(a)) )
            mainNode
          )
        ]
      )
    ])

  mainNode
