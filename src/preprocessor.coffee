{ Block, Comment, Literal, Param, Code, Arr, Value, Call, Assign } = require "./nodes"
util = require "util"


class DefineRewriter

  process : (mainNode) ->

    # Finding `define` statement
    # Has to be a direct child of the main node
    defineBlock = null
    
    mainNode.eachChild (node) ->

      if node.constructor == Comment and /^\s*define/gm.test(node.comment)
        
        defineBlock = 
          sources : []
          targets : []
          node : node
        
        if matches = node.comment.match(/\s*([^\"\n\s\:]+)\s*:\s*([^\"\n\s\:]+)\s*/gm)
          
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



class MacroRewriter
  
  process : (mainNode) ->

    macros = {}

    mainNode.traverseChildren true, (node) ->

      if node.constructor == Assign and node.value.constructor == Code and /Macro$/.test(node.variable.base.value)
        macros[node.variable.base.value] = node

    # console.log util.inspect macros, true, null

    @replacingWalker mainNode, (node, replacer) =>
      
      console.log util.inspect node
      if node.constructor == Call and macros[node.variable.base.value]

        replacer(
          @macroTransformer(
            macros[node.variable.base.value],
            node
          )
        )

    mainNode


  replacingWalker : (node, func) ->

    for childName in node.children
      childNode = node[childName]

      if childNode instanceof Array
        
        childNodes = childNode
        newNodes = []

        i = 0
        while i < childNodes.length
          more = 0
          func(childNodes[i], (newNode) -> 

            if childNode instanceof Array
              childNodes.splice(i, 1, newNode...)
              more = newNode.length
            else
              childNodes[i] = newNode
          )
          
          for j in [i..(i + more)]
            @replacingWalker(childNodes[j], func)
          
          i += more + 1   

      else

        func childNode, (newNode) -> node[childName] = newNode
        @replacingWalker(childNode, func)

      return


  deepCloner : (node) ->

    newNode = {}
    for prop of node
      newNode[prop] = node[prop]

    newNode.constructor = node.constructor
    newNode.__proto__   = node.__proto__

    for childName in node.children
      childNode = node[childName]

      if childNode instanceof Array
        childNodes = childNode
        newNode[childName] = []
        for childNode in childNodes
          newNode[childName].push(@deepCloner(childNode))
      else
        node[childName] = @deepCloner(childNode)

    newNode


  macroTransformer : (macroNode, callNode) ->
    
    macroNode = @deepCloner(macroNode)

    macroArgs = macroNode.value.params.map((a) -> a.name.value)
    callArgs = callNode.args.map((a) -> a.base.value)

    paramsMapping = {}
    changedVariables = {}

    for i in [0...macroArgs.length]
      paramsMapping[macroArgs[i]] = callArgs[i]

    macroNode.traverseChildren true, (node) ->

      if node.constructor == Literal
        if macroArgs.indexOf(node.value) >= 0
          node.value = paramsMapping[node.value]

        else if (newValue = changedVariables[node.value])
          node.value = newValue
    
    macroNode.value.body.expressions



module.exports = (mainNode) ->

  new DefineRewriter().process(mainNode)
