(this.webpackJsonpdashboard=this.webpackJsonpdashboard||[]).push([[131,83],{441:function(e,a,t){"use strict";function n(e){!function(e){function a(e,a){return"___"+e.toUpperCase()+a+"___"}Object.defineProperties(e.languages["markup-templating"]={},{buildPlaceholders:{value:function(t,n,r,o){if(t.language===n){var i=t.tokenStack=[];t.code=t.code.replace(r,(function(e){if("function"===typeof o&&!o(e))return e;for(var r,l=i.length;-1!==t.code.indexOf(r=a(n,l));)++l;return i[l]=e,r})),t.grammar=e.languages.markup}}},tokenizePlaceholders:{value:function(t,n){if(t.language===n&&t.tokenStack){t.grammar=e.languages[n];var r=0,o=Object.keys(t.tokenStack);!function i(l){for(var s=0;s<l.length&&!(r>=o.length);s++){var p=l[s];if("string"===typeof p||p.content&&"string"===typeof p.content){var c=o[r],u=t.tokenStack[c],d="string"===typeof p?p:p.content,g=a(n,c),f=d.indexOf(g);if(f>-1){++r;var m=d.substring(0,f),b=new e.Token(n,e.tokenize(u,t.grammar),"language-"+n,u),k=d.substring(f+g.length),h=[];m&&h.push.apply(h,i([m])),h.push(b),k&&h.push.apply(h,i([k])),"string"===typeof p?l.splice.apply(l,[s,1].concat(h)):p.content=h}}else p.content&&i(p.content)}return l}(t.tokens)}}}})}(e)}e.exports=n,n.displayName="markupTemplating",n.aliases=[]},604:function(e,a,t){"use strict";var n=t(441);function r(e){e.register(n),function(e){var a=/(["'])(?:\\(?:\r\n|[\s\S])|(?!\1)[^\\\r\n])*\1/,t=/\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b|\b0x[\dA-F]+\b/;e.languages.soy={comment:[/\/\*[\s\S]*?\*\//,{pattern:/(\s)\/\/.*/,lookbehind:!0,greedy:!0}],"command-arg":{pattern:/({+\/?\s*(?:alias|call|delcall|delpackage|deltemplate|namespace|template)\s+)\.?[\w.]+/,lookbehind:!0,alias:"string",inside:{punctuation:/\./}},parameter:{pattern:/({+\/?\s*@?param\??\s+)\.?[\w.]+/,lookbehind:!0,alias:"variable"},keyword:[{pattern:/({+\/?[^\S\r\n]*)(?:\\[nrt]|alias|call|case|css|default|delcall|delpackage|deltemplate|else(?:if)?|fallbackmsg|for(?:each)?|if(?:empty)?|lb|let|literal|msg|namespace|nil|@?param\??|rb|sp|switch|template|xid)/,lookbehind:!0},/\b(?:any|as|attributes|bool|css|float|in|int|js|html|list|map|null|number|string|uri)\b/],delimiter:{pattern:/^{+\/?|\/?}+$/,alias:"punctuation"},property:/\w+(?==)/,variable:{pattern:/\$[^\W\d]\w*(?:\??(?:\.\w+|\[[^\]]+]))*/,inside:{string:{pattern:a,greedy:!0},number:t,punctuation:/[\[\].?]/}},string:{pattern:a,greedy:!0},function:[/\w+(?=\()/,{pattern:/(\|[^\S\r\n]*)\w+/,lookbehind:!0}],boolean:/\b(?:true|false)\b/,number:t,operator:/\?:?|<=?|>=?|==?|!=|[+*/%-]|\b(?:and|not|or)\b/,punctuation:/[{}()\[\]|.,:]/},e.hooks.add("before-tokenize",(function(a){var t=!1;e.languages["markup-templating"].buildPlaceholders(a,"soy",/{{.+?}}|{.+?}|\s\/\/.*|\/\*[\s\S]*?\*\//g,(function(e){return"{/literal}"===e&&(t=!1),!t&&("{literal}"===e&&(t=!0),!0)}))})),e.hooks.add("after-tokenize",(function(a){e.languages["markup-templating"].tokenizePlaceholders(a,"soy")}))}(e)}e.exports=r,r.displayName="soy",r.aliases=[]}}]);